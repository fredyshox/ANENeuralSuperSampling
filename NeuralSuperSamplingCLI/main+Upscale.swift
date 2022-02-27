//
//  main+Upscale.swift
//  NeuralSuperSamplingCLI
//
//  Created by Kacper Rączy on 26/02/2022.
//

import Foundation
import Metal
import MetalKit
import NeuralSuperSampling
import ArgumentParser

extension SuperSampling {
    struct Upscale: ParsableCommand {
        enum ModelIdentifier: String, ExpressibleByArgument, CaseIterable {
            case priamp_multiFrame3fps720p
        }
        
        private class Task {
            private let device: MTLDevice
            private let commandQueue: MTLCommandQueue
            private let textureLoader: MTKTextureLoader
            private let model: NSSModel
            private let upscaler: NSSUpscaler
            private var outputTexture: MTLTexture!
            
            var requiredNumberOfFrames: Int {
                return Int(model.inputFrameCount)
            }
            
            init(modelId: ModelIdentifier) {
                device = MTLCreateSystemDefaultDevice()!
                commandQueue = device.makeCommandQueue()!
                textureLoader = MTKTextureLoader(device: device)
                switch modelId {
                case .priamp_multiFrame3fps720p:
                    model = NSSModel.priamp_multiFrame3fps720p()
                    let preprocessor = NSSMultiFrameRGBDMotionPreprocessor(device: device, model: model)
                    let decoder = NSSANEDecoder(device: device, yuvToRgbConversion: false)
                    upscaler = NSSUpscaler(device: device, preprocessor: preprocessor, decoder: decoder, model: model)
                }
            }
            
            private func validateTextureSizes(textures: [MTLTexture]) throws {
                for texture in textures {
                    if texture.width != model.inputWidth || texture.height != model.inputHeight {
                        throw CommandError(message: "Invalid resolution. Expected \(model.inputWidth)x\(model.inputHeight), actual \(model.inputWidth)x\(model.inputHeight)")
                    }
                }
            }
            
            private func setupInternalTexturesIfNeeded(inputColorTexture: MTLTexture) {
                guard outputTexture == nil else {
                    return
                }
                
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: inputColorTexture.pixelFormat,
                    width: inputColorTexture.width * Int(model.scaleFactor),
                    height: inputColorTexture.height * Int(model.scaleFactor),
                    mipmapped: false
                )
                descriptor.usage.update(with: [.shaderWrite, .renderTarget])
                descriptor.storageMode = .shared
                
                outputTexture = device.makeTexture(descriptor: descriptor)
            }
            
            func processImage(colorURLs: [URL], depthURLs: [URL], motionURLs: [URL], outputURL: URL) throws {
                guard
                    UInt(colorURLs.count) == model.inputFrameCount,
                    colorURLs.count == depthURLs.count,
                    colorURLs.count == motionURLs.count
                else {
                    fatalError("Invalid number of frames provided for processing")
                }
                
                let commandBuffer = commandQueue.makeCommandBuffer()!
                for index in colorURLs.indices {
                    let colorTexture = try textureLoader.newTexture(URL: colorURLs[index], options: [.SRGB: false])
                    let depthTexture = try textureLoader.newTexture(URL: depthURLs[index], options: [:])
                    let motionTexture = try textureLoader.newTexture(URL: motionURLs[index], options: [:])
                    setupInternalTexturesIfNeeded(inputColorTexture: colorTexture)
                    try validateTextureSizes(textures: [colorTexture, depthTexture, motionTexture])
                    
                    upscaler.process(
                        inputColorTexture: colorTexture,
                        inputDepthTexture: depthTexture,
                        inputMotionTexture: motionTexture,
                        outputTexture: outputTexture,
                        usingCommandBuffer: commandBuffer
                    )
                }
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                CGImage.fromTexture(outputTexture).saveToPng(at: outputURL)
            }
        }
        
        static var configuration = CommandConfiguration(abstract: "Perform neural supersampling on images")
        
        @Argument(help: "Input directory")
        var inputDirectory: String
        
        @Argument(help: "Output directory")
        var outputDirectory: String
        
        @Option(help: "NSS model, choices: \(ModelIdentifier.allCases.map { $0.rawValue })")
        var model: ModelIdentifier = .priamp_multiFrame3fps720p
        
        @Flag(name: .shortAndLong, help: "Enable verbose output")
        var verbose: Bool = false
        
        func run() throws {
            let task = Task(modelId: model)
            let filenameParser = FilenameParser()
            
            let inputDirectoryURL = URL(fileURLWithPath: inputDirectory)
            let outputDirectoryURL = URL(fileURLWithPath: outputDirectory)
            let fm = FileManager.default
            
            let inputURLs = try fm.contentsOfDirectory(at: inputDirectoryURL, includingPropertiesForKeys: nil, options: [])
            var colorFramesByIndex: [Int: URL] = [:]
            var depthFramesByIndex: [Int: URL] = [:]
            var motionFramesByIndex: [Int: URL] = [:]
            
            for fileURL in inputURLs {
                guard fm.isFile(atPath: fileURL.path) else {
                    continue
                }
                
                let filename = fileURL.lastPathComponent
                if let index = filenameParser.parseColorIndex(ofFilename: filename) {
                    colorFramesByIndex[index] = fileURL
                } else if let index = filenameParser.parseDepthIndex(ofFilename: filename) {
                    depthFramesByIndex[index] = fileURL
                } else if let index = filenameParser.parseMotionIndex(ofFilename: filename) {
                    motionFramesByIndex[index] = fileURL
                }
            }
            
            vPrint("Discovered \(colorFramesByIndex.count) color images, \(depthFramesByIndex.count) depth images, \(motionFramesByIndex.count) motion images at \(inputDirectory)")
            
            for (index, colorURL) in colorFramesByIndex {
                let precedingAndCurrentIndices = (index - (task.requiredNumberOfFrames - 1))..<index
                
                let previousColorURLs = precedingAndCurrentIndices.compactMap { colorFramesByIndex[$0] }
                let previousDepthURLs = precedingAndCurrentIndices.compactMap { depthFramesByIndex[$0] }
                let previousMotionURLs = precedingAndCurrentIndices.compactMap { motionFramesByIndex[$0] }
                guard
                    let depthURL = depthFramesByIndex[index],
                    let motionURL = motionFramesByIndex[index],
                    previousColorURLs.count == (task.requiredNumberOfFrames - 1),
                    previousDepthURLs.count == (task.requiredNumberOfFrames - 1),
                    previousMotionURLs.count == (task.requiredNumberOfFrames - 1)
                else {
                    continue
                }
                
                let outputURL = outputDirectoryURL
                    .appendingPathComponent(colorURL.lastPathComponent)
                guard !fm.fileExists(atPath: outputURL.path) else {
                    throw CommandError(message: "File at: \(outputURL) already exist")
                }
                
                vPrint("Upscaling image at: \(colorURL)")
                try task.processImage(
                    colorURLs: previousColorURLs + [colorURL],
                    depthURLs: previousDepthURLs + [depthURL],
                    motionURLs: previousMotionURLs + [motionURL],
                    outputURL: outputURL
                )
                vPrint("Output image written to: \(outputURL)")
            }
        }
        
        private func vPrint(_ item: Any) {
            if verbose {
                print(item)
            }
        }
    }
}
