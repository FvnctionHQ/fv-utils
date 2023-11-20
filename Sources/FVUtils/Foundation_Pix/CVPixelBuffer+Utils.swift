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
    
    func centerRect(side: Int) -> CVPixelBuffer? {
        
        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
        }
        let bufferWidthY = CVPixelBufferGetWidthOfPlane(self, 0)
        let bufferHeightY = CVPixelBufferGetHeightOfPlane(self, 0)
        
        let bufferWidthUV = CVPixelBufferGetWidthOfPlane(self, 1)
        let bufferHeightUV = CVPixelBufferGetHeightOfPlane(self, 1)
        
        let cropWidth = side
        let cropHeight = side

        /// Calculate the top-left corner of the crop rectangle to center it
        let xOffsetY = (bufferWidthY - cropWidth) / 2
        let yOffsetY = (bufferHeightY - cropHeight) / 2
        
        /// UV channel has different offsets as its smaller
        let xOffsetUV = ((bufferWidthUV - cropWidth) / 2) / 2
        let yOffsetUV = ((bufferHeightUV - cropHeight) / 2) / 2

        
        /// Get the original base addresses
        let baseAddressY = CVPixelBufferGetBaseAddressOfPlane(self, 0)
        let baseAddressUV = CVPixelBufferGetBaseAddressOfPlane(self, 1)
        
        let strideY = CVPixelBufferGetBytesPerRowOfPlane(self, 0)
        let strideUV = CVPixelBufferGetBytesPerRowOfPlane(self, 1)
        let byteOffsetY = yOffsetY * strideY + xOffsetY
        let byteOffsetUV = yOffsetUV * strideUV + xOffsetUV * 2
        
        /// Create pointers to the offset addresses for each plane
        let offsetBaseAddressY = baseAddressY?.advanced(by: byteOffsetY)
        let offsetBaseAddressUV = baseAddressUV?.advanced(by: byteOffsetUV)

        /// Adjust base addresses according to cropRect
        var baseAddresses: [UnsafeMutableRawPointer?] = [offsetBaseAddressY, offsetBaseAddressUV]
        
        /// Strides (bytes per row) remain the same
        var bytesPerRowOfPlanes: [Int] = [strideY, strideUV]
        
        var newPixelBuffer: CVPixelBuffer?
        var zeroInt: Int = 0
        var zeroIntAnother: Int = 0

        let result = CVPixelBufferCreateWithPlanarBytes(
            nil, // allocator
            cropWidth, // width of the cropped area
            cropHeight, // height of the cropped area
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, // pixel format
            nil, // dataPtr: pass nil because we're using the existing memory
            0, // dataSize: pass 0 because we're using the existing memory
            2, // plane count
            &baseAddresses, // new base addresses for the Y plane
            &zeroInt,
            &zeroIntAnother, // release callback: pass nil because we don't want to release the memory
            &bytesPerRowOfPlanes, // stride for the Y plane
            nil,
            nil,
            nil,
            &newPixelBuffer // dest pixel buffer
        )
        
        if result == kCVReturnSuccess {
            
            return newPixelBuffer
        }
       return nil

    }
    
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
