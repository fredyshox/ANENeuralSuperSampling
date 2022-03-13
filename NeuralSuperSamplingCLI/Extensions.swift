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

extension MTLPixelFormat {
    var bitsPerComponent: Int {
        switch self {
        case .bgra8Unorm:
            return 8
        case .rgba16Float:
            return 16
        default:
            fatalError("Unsupported pixel format: \(self.rawValue)")
        }
    }
    
    var bytesPerPixel: Int {
        switch self {
        case .bgra8Unorm:
            return 4
        case .rgba16Float:
            return 8
        default:
            fatalError("Unsupported pixel format: \(self.rawValue)")
        }
    }
    
    var bitmapInfo: CGBitmapInfo {
        switch self {
        case .bgra8Unorm:
            return [
                .byteOrder32Little, // reverse bytes => bgra -> argb
                .init(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
            ]
        case .rgba16Float:
            return [
                .floatComponents,
                .byteOrder16Little,
                .init(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
            ]
        default:
            fatalError("Unsupported pixel format: \(self.rawValue)")
        }
    }
}

extension CGImage {
    static func fromTexture(_ texture: MTLTexture) -> CGImage {
        let pixelFormat = texture.pixelFormat
        let allocationSize = texture.width * texture.height * pixelFormat.bytesPerPixel
        let bytesPerRow = texture.width * pixelFormat.bytesPerPixel
        let bitsPerComponent = pixelFormat.bitsPerComponent
        let bitsPerPixel = pixelFormat.bytesPerPixel * 8
        let bufferPointer = malloc(allocationSize)!
        
        texture.getBytes(
            bufferPointer,
            bytesPerRow: bytesPerRow,
            from: MTLRegionMake2D(0, 0, texture.width, texture.height),
            mipmapLevel: 0
        )
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = pixelFormat.bitmapInfo
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
    
    @discardableResult
    func saveToExr(at url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.ilm.openexr-image" as CFString, 1, nil) else {
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
