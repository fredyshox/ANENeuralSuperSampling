//
//  main.swift
//  NeuralSuperSamplingCLI
//
//  Created by Kacper Rączy on 09/01/2022.
//

import Foundation
import Metal
import CoreGraphics
import CoreImage
import ArgumentParser
import NeuralSuperSampling

func textureToCGImage(texture: MTLTexture) -> CGImage {
    guard let ciImage = CIImage(mtlTexture: texture, options: nil) else {
        fatalError("Cannot convert texture to CIImage")
    }

    let context = CIContext(options: nil)
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
        fatalError("Cannot convert CIImage to CGImage")
    }

    return cgImage
}

func cgImageToFile(image: CGImage, url: URL) -> Bool {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        fatalError("Cannot aquire destination")
    }

    CGImageDestinationAddImage(destination, image, nil)
    let res = CGImageDestinationFinalize(destination)
    
    return res
}

struct SuperSampling: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "NeuralSuperSampling CLI",
        subcommands: [Upscale.self]
    )
    
    struct Upscale: ParsableCommand {
        
    }
}

func triggerProgrammaticCapture(_ device: MTLDevice) {
    let captureManager = MTLCaptureManager.shared()
    let captureDescriptor = MTLCaptureDescriptor()
    captureDescriptor.captureObject = device
    captureDescriptor.outputURL = URL(fileURLWithPath: "./capture.gputrace")
    
    do {
        try captureManager.startCapture(with: captureDescriptor)
    } catch let error {
        NSLog("Failed to start capture, error \(error)")
    }
}

func endProgrammaticCapture() {
    MTLCaptureManager.shared().stopCapture()
}

func main() {
    let device = MTLCreateSystemDefaultDevice()!
    let queue = device.makeCommandQueue()!
    let event = device.makeSharedEvent()!
    let dispatchQueue = DispatchQueue(label: "com.myqueue")
    let eventListener = MTLSharedEventListener(dispatchQueue: dispatchQueue)

    let metalBuffer = device.makeBuffer(length: 2048, options: MTLResourceOptions.storageModeShared)!

    triggerProgrammaticCapture(device)
    
    let buffer = queue.makeCommandBuffer()!

    event.notify(eventListener, atValue: 1) { event, value in
        let pointer = metalBuffer.contents().assumingMemoryBound(to: UInt8.self)
        for i in 0..<512 {
            (pointer + i).pointee = 55;
        }

        NSLog("Event notification - value: \(value), buffer status: \(buffer.status.rawValue)")
        event.signaledValue = 2
    }

    // work part 1
    let encoder1 = buffer.makeBlitCommandEncoder()!
    encoder1.fill(buffer: metalBuffer, range: .init(0...127), value: 22)
    encoder1.endEncoding()

    buffer.encodeSignalEvent(event, value: 1)
    buffer.encodeWaitForEvent(event, value: 2)

     let encoder2 = buffer.makeBlitCommandEncoder()!
     encoder2.fill(buffer: metalBuffer, range: .init(512...767), value: 255)
     encoder2.endEncoding()

    buffer.addScheduledHandler { buffer in
        NSLog("Buffer scheduled - value: \(event.signaledValue)")
    }
    buffer.addCompletedHandler { buffer in
        NSLog("Buffer completed - value: \(event.signaledValue)")
    }

    buffer.commit()
    
    buffer.waitUntilCompleted()
    
    endProgrammaticCapture()
}

main()
