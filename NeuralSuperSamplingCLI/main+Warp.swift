//
//  main+Warp.swift
//  NeuralSuperSamplingCLI
//
//  Created by Kacper Rączy on 24/02/2022.
//

import Foundation
import Metal
import MetalKit
import NeuralSuperSampling
import ArgumentParser

extension SuperSampling {
    struct Warp: ParsableCommand {
        private class Task {
            private let device: MTLDevice
            private let commandQueue: MTLCommandQueue
            private let textureLoader: MTKTextureLoader
            private let processing: NSSMetalProcessing
            private let scaleFactor: Int
            private var immediateTexture: MTLTexture!
            private var outputTexture: MTLTexture!
    
            init(scaleFactor: UInt) {
                self.device = MTLCreateSystemDefaultDevice()!
                self.commandQueue = device.makeCommandQueue()!
                self.textureLoader = MTKTextureLoader(device: device)
                self.processing = NSSMetalProcessing(device: device, scaleFactor: scaleFactor, outputBufferStride: .zero)
                self.scaleFactor = Int(scaleFactor)
            }
            
            private func setupInternalTexturesIfNeeded(inputTexture: MTLTexture) {
                guard (immediateTexture == nil || outputTexture == nil) else {
                    return
                }
                
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: inputTexture.pixelFormat,
                    width: inputTexture.width * scaleFactor,
                    height: inputTexture.height * scaleFactor,
                    mipmapped: false
                )
                descriptor.usage.update(with: [.shaderWrite, .renderTarget])
                descriptor.storageMode = .shared
                
                immediateTexture = device.makeTexture(descriptor: descriptor)
                outputTexture = device.makeTexture(descriptor: descriptor)
            }
            
            func processImage(colorURL: URL, motionURLs: [URL], outputURL: URL) throws {
                let colorTexture = try textureLoader.newTexture(URL: colorURL, options: [.SRGB: false])
                setupInternalTexturesIfNeeded(inputTexture: colorTexture)
                
                let commandBuffer = commandQueue.makeCommandBuffer()!
                processing.clear(immediateTexture, with: commandBuffer)
                processing.clear(outputTexture, with: commandBuffer)
                processing.upsampleInputTexture(colorTexture, outputTexture: immediateTexture, with: commandBuffer)
                
                var motionTexture: MTLTexture!
                for motionURL in motionURLs {
                    motionTexture = try textureLoader.newTexture(URL: motionURL, options: [:])
                    processing.warpInputTexture(immediateTexture, motionTexture: motionTexture, outputTexture: outputTexture, with: commandBuffer)
                }
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                CGImage.fromTexture(outputTexture).saveToPng(at: outputURL)
            }
        }
        
        static var configuration = CommandConfiguration(abstract: "Upsample & Warp images using motion vectors")
        
        @Argument(help: "Input directory")
        var inputDirectory: String
        
        @Argument(help: "Output directory")
        var outputDirectory: String
        
        @Option(help: "Number of frames")
        var frameCount: Int = 3
        
        @Option(help: "Scale factor")
        var scaleFactor: UInt = 2
        
        @Flag(name: .shortAndLong, help: "Enable verbose output")
        var verbose: Bool = false
        
        func run() throws {
            let task = Task(scaleFactor: scaleFactor)
            let filenameParser = FilenameParser()
            
            let inputDirectoryURL = URL(fileURLWithPath: inputDirectory)
            let outputDirectoryURL = URL(fileURLWithPath: outputDirectory)
            let fm = FileManager.default
            
            let inputURLs = try fm.contentsOfDirectory(at: inputDirectoryURL, includingPropertiesForKeys: nil, options: [])
            var motionFramesByIndex: [Int: URL] = [:]
            var colorFramesByIndex: [Int: URL] = [:]
            
            for fileURL in inputURLs {
                guard fm.isFile(atPath: fileURL.path) else {
                    continue
                }
                
                if let index = filenameParser.parseColorIndex(ofFilename: fileURL.lastPathComponent) {
                    colorFramesByIndex[index] = fileURL
                } else if let index = filenameParser.parseMotionIndex(ofFilename: fileURL.lastPathComponent) {
                    motionFramesByIndex[index] = fileURL
                }
            }
            
            vPrint("Discovered \(colorFramesByIndex.count) color images, \(motionFramesByIndex.count) motion images at \(inputDirectory)")
            
            for (index, fileURL) in colorFramesByIndex {
                let motionURLs = ((index+1)..<(index+frameCount)).compactMap { motionFramesByIndex[$0] }
                guard motionURLs.count == (frameCount - 1) else {
                    continue
                }
                
                for warpCount in 1...motionURLs.count {
                    let outputURL = outputDirectoryURL
                        .appendingPathComponent(fileURL.deletingPathExtension().lastPathComponent + "+\(warpCount)")
                        .appendingPathExtension(fileURL.pathExtension)
                    guard !fm.fileExists(atPath: outputURL.path) else {
                        throw CommandError(message: "File at \(outputURL) already exist")
                    }
                    
                    vPrint("Performing \(warpCount) warps to image at: \(fileURL)")
                    try task.processImage(colorURL: fileURL, motionURLs: Array(motionURLs.prefix(upTo: warpCount)), outputURL: outputURL)
                    vPrint("Output image written to: \(outputURL)")
                }
            }
        }
        
        private func vPrint(_ item: Any) {
            if verbose {
                print(item)
            }
        }
    }
}
