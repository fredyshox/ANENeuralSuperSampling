//
//  Extensions.swift
//  NeuralSuperSamplingCLI
//
//  Created by Kacper Rączy on 24/02/2022.
//

import Foundation
import CoreGraphics
import CoreImage
import Metal

extension CGImage {
    static func fromTexture(_ texture: MTLTexture) -> CGImage {
        guard texture.pixelFormat == .bgra8Unorm else {
            fatalError("Pixel format of texture must be .bgra8Unorm")
        }
        
        let allocationSize = texture.width * texture.height * 4
        let bytesPerRow = texture.width * 4
        let bitsPerComponent = 8
        let bitsPerPixel = 32
        let bufferPointer = malloc(allocationSize)!
        
        texture.getBytes(
            bufferPointer,
            bytesPerRow: bytesPerRow,
            from: MTLRegionMake2D(0, 0, texture.width, texture.height),
            mipmapLevel: 0
        )
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: CGBitmapInfo = [
            .byteOrder32Little, // reverse bytes => bgra -> argb
            .init(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
        ]
        guard
            let dataProvider = CGDataProvider(
                dataInfo: nil,
                data: bufferPointer,
                size: allocationSize,
                releaseData: { _, buffer, _ in buffer.deallocate() }
            ),
            let cgImage = CGImage(
                width: texture.width,
                height: texture.height,
                bitsPerComponent: bitsPerComponent,
                bitsPerPixel: bitsPerPixel,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: dataProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            fatalError("Failed to create CGDataProvider provider")
        }
        
        return cgImage
    }
    
    @discardableResult
    func saveToPng(at url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            NSLog("Failed to save png image at: \(url)")
            return false
        }

        CGImageDestinationAddImage(destination, self, nil)
        let res = CGImageDestinationFinalize(destination)
        
        return res
    }
}

extension FileManager {
    func isFile(atPath path: String) -> Bool {
        var isDir: ObjCBool = false
        if fileExists(atPath: path, isDirectory: &isDir) {
            return !isDir.boolValue
        } else {
            return false
        }
    }
}
