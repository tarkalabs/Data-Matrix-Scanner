# Data-Matrix-Scanner
Showcases different approaches to scan data matrix code from a metal surface.
The project hoighlights scanning using three different techniques:
1) AVCaptureMetadataOutput()
2) Vision 
3) Vision + Pre Processor which converts the CoreVideoImageBuffer (CVImageBuffer) to GrayScale

```
private func preprocessImagePipeLine1(_ ciImage: CIImage?) -> CIImage? {
    guard let ciImage else { return nil }

    let filter = CIFilter(name: "CIColorControls")
    filter?.setValue(ciImage, forKey: kCIInputImageKey)
    filter?.setValue(0.0, forKey: kCIInputBrightnessKey)
    filter?.setValue(0.0, forKey: kCIInputSaturationKey)
    filter?.setValue(1.1, forKey: kCIInputContrastKey)

    guard let intermediateImage = filter?.outputImage else { return nil }

    let filter1 = CIFilter(name:"CIExposureAdjust")
    filter1?.setValue(intermediateImage, forKey: kCIInputImageKey)
    filter1?.setValue(0.7, forKey: kCIInputEVKey)

    return filter1?.outputImage
}
```
# Screen Recording
https://user-images.githubusercontent.com/16992520/230060827-3ae9162a-c1f5-4894-a141-be2cfd1a6f59.mp4


# Test Data Matrix code on Metal surface
| | |
|:-------------------------:|:-------------------------:|
|<img width="1604" alt="DMC example 1" src="https://user-images.githubusercontent.com/16992520/230059783-b0caea6d-7f9c-4550-bd4f-f5121b8db63c.JPG"> |  <img width="1604" alt="DMC Example 2" src="https://user-images.githubusercontent.com/16992520/230059813-22ec783b-28bd-4502-bb4b-b441049a2eed.jpeg">|
