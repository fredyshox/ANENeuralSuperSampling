//
//  main.swift
//  NeuralSuperSamplingCLI
//
//  Created by Kacper Rączy on 09/01/2022.
//

import Foundation
import ArgumentParser

struct SuperSampling: ParsableCommand {
    struct CommandError: LocalizedError {
        let message: String
        
        var errorDescription: String? {
            message
        }
    }
    
    struct FilenameParser {
        private let colorFrameFilenameRegex = try! NSRegularExpression(pattern: #"COLOR\.([0-9]+)\.png"#, options: [])
        private let motionFrameFilenameRegex = try! NSRegularExpression(pattern: #"MOTIONVECTORS\.([0-9]+)\.exr"#, options: [])
        private let depthFrameFilenameRegex = try! NSRegularExpression(pattern: #"DEPTH\.([0-9]+)\.exr"#, options: [])
        
        func parseColorIndex(ofFilename filename: String) -> Int? {
            parseIndex(ofFilename: filename, withRegex: colorFrameFilenameRegex)
        }
        
        func parseMotionIndex(ofFilename filename: String) -> Int? {
            parseIndex(ofFilename: filename, withRegex: motionFrameFilenameRegex)
        }
        
        func parseDepthIndex(ofFilename filename: String) -> Int? {
            parseIndex(ofFilename: filename, withRegex: depthFrameFilenameRegex)
        }
        
        private func parseIndex(ofFilename filename: String, withRegex regex: NSRegularExpression) -> Int? {
            let filenameRange = NSRange(filename.startIndex..<filename.endIndex, in: filename)
            guard
                let match = regex.firstMatch(in: filename, options: [], range: filenameRange),
                let matchRange = Range(match.range(at: 1), in: filename)
            else {
                return nil
            }
            
            return Int(filename[matchRange])
        }
    }
    
    static let configuration = CommandConfiguration(
        abstract: "NeuralSuperSampling CLI",
        subcommands: [Upscale.self, Warp.self]
    )
}

SuperSampling.main()
