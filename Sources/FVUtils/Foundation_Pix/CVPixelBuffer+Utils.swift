//
//  File.swift
//  
//  Created by Alex Linkow on 20.11.23.
//

import Foundation
import AVFoundation
import CoreImage
import VideoToolbox
import Accelerate

public extension CVPixelBuffer {
    
    func cgImageFast() -> CGImage? {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(self, options: nil, imageOut: &cgImage)
        return cgImage
      }

    func cgImage(context: CIContext) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: self)
        let rect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(self),
                                      height: CVPixelBufferGetHeight(self))
        return context.createCGImage(ciImage, from: rect)
      }
    
    func centerThumbnail_32BGRA(size: CGSize ) -> CVPixelBuffer? {

      let imageWidth = CVPixelBufferGetWidth(self)
      let imageHeight = CVPixelBufferGetHeight(self)
      let pixelBufferType = CVPixelBufferGetPixelFormatType(self)

      assert(pixelBufferType == kCVPixelFormatType_32BGRA)

      let inputImageRowBytes = CVPixelBufferGetBytesPerRow(self)
      let imageChannels = 4

      let thumbnailSize = min(imageWidth, imageHeight)
      CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))

      var originX = 0
      var originY = 0

      if imageWidth > imageHeight {
        originX = (imageWidth - imageHeight) / 2
      }
      else {
        originY = (imageHeight - imageWidth) / 2
      }

      // Finds the biggest square in the pixel buffer and advances rows based on it.
      guard let inputBaseAddress = CVPixelBufferGetBaseAddress(self)?.advanced(by: originY * inputImageRowBytes + originX * imageChannels) else {
        return nil
      }

      // Gets vImage Buffer from input image
      var inputVImageBuffer = vImage_Buffer(data: inputBaseAddress, height: UInt(thumbnailSize), width: UInt(thumbnailSize), rowBytes: inputImageRowBytes)

      let thumbnailRowBytes = Int(size.width) * imageChannels
      guard  let thumbnailBytes = malloc(Int(size.height) * thumbnailRowBytes) else {
        return nil
      }

      // Allocates a vImage buffer for thumbnail image.
      var thumbnailVImageBuffer = vImage_Buffer(data: thumbnailBytes, height: UInt(size.height), width: UInt(size.width), rowBytes: thumbnailRowBytes)

      // Performs the scale operation on input image buffer and stores it in thumbnail image buffer.
      let scaleError = vImageScale_ARGB8888(&inputVImageBuffer, &thumbnailVImageBuffer, nil, vImage_Flags(0))

      CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))

      guard scaleError == kvImageNoError else {
        return nil
      }

      let releaseCallBack: CVPixelBufferReleaseBytesCallback = {mutablePointer, pointer in

        if let pointer = pointer {
          free(UnsafeMutableRawPointer(mutating: pointer))
        }
      }

      var thumbnailPixelBuffer: CVPixelBuffer?

      // Converts the thumbnail vImage buffer to CVPixelBuffer
      let conversionStatus = CVPixelBufferCreateWithBytes(nil, Int(size.width), Int(size.height), pixelBufferType, thumbnailBytes, thumbnailRowBytes, releaseCallBack, nil, nil, &thumbnailPixelBuffer)

      guard conversionStatus == kCVReturnSuccess else {

        free(thumbnailBytes)
        return nil
      }

      return thumbnailPixelBuffer
    }

    
    func resized(pixelBufferPoolOfScaledSize: CVPixelBufferPool) -> CVPixelBuffer? {
        let lumaWidth = CVPixelBufferGetWidthOfPlane(self, 0)
        let lumaHeight = CVPixelBufferGetHeightOfPlane(self, 0)
        
        var scaledPixelBuffer: CVPixelBuffer?
        
        

       
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPoolOfScaledSize, &scaledPixelBuffer)
        
        guard let buffer = scaledPixelBuffer else {
            return nil
        }
        
        var scalingSession: VTPixelTransferSession?
        let scalingStatus = VTPixelTransferSessionCreate(allocator: kCFAllocatorDefault, pixelTransferSessionOut: &scalingSession)
        _ = VTSessionSetProperty(scalingSession!, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        
        
        if scalingStatus != noErr {

            return nil
        }
        
        let resizeStatus = VTPixelTransferSessionTransferImage(scalingSession!, from: self, to: buffer) //VTImageScalingSessionTransferImage(scalingSession!, pixelBuffer, buffer)
        if resizeStatus != noErr {

            return nil
        }
        
        return buffer
    }
    
    func cgImageResized(_ size: CGSize) -> CGImage? {
        
        let ciImage = CIImage(cvPixelBuffer: self)

        let scaleFilter = CIFilter(name: "CILanczosScaleTransform")!
        scaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
        scaleFilter.setValue(0.5, forKey: kCIInputScaleKey)
        let scaledImage = scaleFilter.outputImage!

        let cropRect = CGRect(x: (scaledImage.extent.width - size.width) / 2,
                              y: (scaledImage.extent.height - size.height) / 2,
                              width: size.width,
                              height: size.height)
        let cropFilter = CIFilter(name: "CICrop")!
        cropFilter.setValue(scaledImage, forKey: kCIInputImageKey)
        cropFilter.setValue(cropRect, forKey: "inputRectangle")
        let croppedImage = cropFilter.outputImage!

        let context = CIContext()
        return context.createCGImage(croppedImage, from: croppedImage.extent)


    }
    
    func cgImageCropped(roi: CGRect, ctx: CIContext) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: self)
       // let extent = ciImage.extent

        let smallestDimension = min(roi.width, roi.height)
        let largestDimension = max(roi.width, roi.height)

        let originX = (roi.width - smallestDimension) / 2.0
        let originY = (roi.height - smallestDimension) / 2.0
        let cropRect = CGRect(x: originX, y: originY, width: smallestDimension, height: smallestDimension)

        let outputImage = ciImage.cropped(to: cropRect)
        let out = ctx.createCGImage(ciImage, from: cropRect)
        return out
    }
}

func createPixelBufferPool(width: Int, height: Int, pixelFormat: OSType) -> CVPixelBufferPool? {
    var outputPool: CVPixelBufferPool?
    
    let poolAttributes: [String: Any] = [
        kCVPixelBufferPoolMinimumBufferCountKey as String: 3
    ]
    
    let pixelBufferAttributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:]
    ]
    
    let status = CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttributes as CFDictionary, pixelBufferAttributes as CFDictionary, &outputPool)
    
    guard status == kCVReturnSuccess else {
        return nil
    }
    
    return outputPool
}
