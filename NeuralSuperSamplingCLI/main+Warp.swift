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
            private let floatOutput: Bool
            private var immediateTexture: MTLTexture!
            private var outputTexture: MTLTexture!
            
            init(scaleFactor: UInt, floatOutput: Bool) {
                self.device = MTLCreateSystemDefaultDevice()!
                self.commandQueue = device.makeCommandQueue()!
                self.textureLoader = MTKTextureLoader(device: device)
                self.processing = NSSMetalProcessing(device: device, scaleFactor: scaleFactor, outputBufferStride: .zero)
                self.scaleFactor = Int(scaleFactor)
                self.floatOutput = floatOutput
            }
            
            private func setupInternalTexturesIfNeeded(inputTexture: MTLTexture) {
                guard (immediateTexture == nil || outputTexture == nil) else {
                    return
                }
                
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: floatOutput ? MTLPixelFormat.rgba16Float : inputTexture.pixelFormat,
                    width: inputTexture.width * scaleFactor,
                    height: inputTexture.height * scaleFactor,
                    mipmapped: false
                )
                descriptor.usage.update(with: [.shaderWrite, .renderTarget])
                descriptor.storageMode = .shared
                
                immediateTexture = device.makeTexture(descriptor: descriptor)
                outputTexture = device.makeTexture(descriptor: descriptor)
            }
            
            func processImage(inputURL: URL, motionURLs: [URL], outputURL: URL) throws {
                let inputTexture = try textureLoader.newTexture(URL: inputURL, options: [.SRGB: false])
                setupInternalTexturesIfNeeded(inputTexture: inputTexture)
                
                let commandBuffer = commandQueue.makeCommandBuffer()!
                processing.clear(immediateTexture, with: commandBuffer)
                processing.clear(outputTexture, with: commandBuffer)
                processing.upsampleInputTexture(inputTexture, outputTexture: motionURLs.isEmpty ? outputTexture : immediateTexture, with: commandBuffer)
                
                var motionTexture: MTLTexture!
                for motionURL in motionURLs {
                    motionTexture = try textureLoader.newTexture(URL: motionURL, options: [:])
                    processing.warpInputTexture(immediateTexture, motionTexture: motionTexture, outputTexture: outputTexture, with: commandBuffer)
                }
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                let image = CGImage.fromTexture(outputTexture)
                if outputURL.pathExtension == "exr" {
                    image.saveToExr(at: outputURL)
                } else {
                    image.saveToPng(at: outputURL)
                }
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
        
        @Flag(help: "Output .exr with floating point components")
        var floatOutput: Bool = false
        
        @Flag(help: "Read depth images instead of color")
        var depthMode: Bool = false
        
        @Flag(name: .shortAndLong, help: "Enable verbose output")
        var verbose: Bool = false
        
        func run() throws {
            let task = Task(scaleFactor: scaleFactor, floatOutput: floatOutput)
            let filenameParser = FilenameParser()
            
            let inputDirectoryURL = URL(fileURLWithPath: inputDirectory)
            let outputDirectoryURL = URL(fileURLWithPath: outputDirectory)
            let fm = FileManager.default
            
            let inputURLs = try fm.contentsOfDirectory(at: inputDirectoryURL, includingPropertiesForKeys: nil, options: [])
            var motionFramesByIndex: [Int: URL] = [:]
            var inputFramesByIndex: [Int: URL] = [:]
            
            for fileURL in inputURLs {
                guard fm.isFile(atPath: fileURL.path) else {
                    continue
                }
                
                if !depthMode, let index = filenameParser.parseColorIndex(ofFilename: fileURL.lastPathComponent) {
                    inputFramesByIndex[index] = fileURL
                } else if depthMode, let index = filenameParser.parseDepthIndex(ofFilename: fileURL.lastPathComponent) {
                    inputFramesByIndex[index] = fileURL
                } else if let index = filenameParser.parseMotionIndex(ofFilename: fileURL.lastPathComponent) {
                    motionFramesByIndex[index] = fileURL
                }
            }
            
            vPrint("Discovered \(inputFramesByIndex.count) \(!depthMode ? "color" : "depth") images, \(motionFramesByIndex.count) motion images at \(inputDirectory)")
            
            for (index, fileURL) in inputFramesByIndex {
                let motionURLs = ((index+1)..<(index+frameCount)).compactMap { motionFramesByIndex[$0] }
                
                for warpCount in 0...motionURLs.count {
                    let outputURL = outputDirectoryURL
                        .appendingPathComponent(fileURL.deletingPathExtension().lastPathComponent + "+\(warpCount)")
                        .appendingPathExtension(floatOutput ? "exr" : fileURL.pathExtension)
                    guard !fm.fileExists(atPath: outputURL.path) else {
                        vPrint("File at \(outputURL) already exists")
                        continue
                    }
                    
                    vPrint("Performing \(warpCount) warps to image at: \(fileURL)")
                    try task.processImage(inputURL: fileURL, motionURLs: Array(motionURLs.prefix(upTo: warpCount)), outputURL: outputURL)
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
