# BrazilNut

Swift library for image/video processing based on Core Image.

This library is highly inspired by GPUImage and BBMetalImage, The difference is that it is based on CoreImage.
So using this library makes it very easy to apply Apple CIFilters.

# Requirements

- iOS 13.0+
- Swift 5

# Installation

Swift Package Manager

```
https://github.com/hxperl/BrazilNut.git
```

# Basic Concepts

1. Source -> Consumer

![concept1](https://github.com/hxperl/BrazilNut/tree/master/Images/concept1.png)

2. Source -> Filter -> Consumer

![concept2](https://github.com/hxperl/BrazilNut/tree/master/Images/concept2.png)


# How to Create Filter & Apply

### 1. Open Camera

```swift
var camera: Camera!
var renderView: RenderView!

override func viewDidLoad() {
    ...
    camera = try! Camera(sessionPreset: .hd1920x1080)
    camera.add(consumer: renderView)
}

override func viewWillAppear(_ animated: Bool) {
    ...
    camera.startCapture()
}
```

#### CURRENT Chain State
camera  --> renderView

### 2. Create a Filter Class

Create a custom filter by inheriting the `ImageRelay` class,
Just override the `newImageAvailable` method.
(This example shows how to use the CIFilters.)

```swift
class MyFilter: ImageRelay {
	override func newImageAvailable(_ bnImage: BNImage, from source: ImageSource) {
		let inputImage = bnImage.image
		let inputType = bnImage.type

		let comic = CIFilter(name: "CIComicEffect")
        comic?.setValue(inputImage, forKey: kCIInputImageKey)

		if let outputImage = comic?.outputImage {
            /// Create a new BNImage
			let newImage = BNImage(image: outputImage, type: inputType)
            /// Deliver images to the next consumers
			for consumer in consumers {
				consumer.newImageAvailable(newImage, from: self)
			}
		}
	}
}
```

### 3. Add chain to Camera

Using the `add(chain :)`, the chain state is applied as follows.

```swift
var myFilter = MyFilter()
camera.add(chain: myFilter)
```

#### CURRENT Chain State
camera --> myFilter --> renderView

### 4. Remove chain from Camera

Only the chain itself is removed and the rest of the chain is connected.
```swift
myFilter.removeSelf()
```

#### CURRENT Chain State
camera --> renderView