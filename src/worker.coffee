"use strict"

console.log "Worker Loaded..."

# Utilities
floorPositiveNum = (num) ->
    num | 0

roundPositiveNum = (num) ->
    (.5 + num) | 0

ceilPositiveNum = (num) ->
    tmp = num | 0
    if tmp is num
        return tmp | 0
    else
        return (tmp + 1 | 0) | 0

pixelateFrame = (frame, l, t, w, h, frameWidth) -> # left, top, width, height
    # This function avoids calling getImageData() multiple times, which is very slow.
    # This function can safely assume that l + w <= frameWidth; t + h <= frameHeight
    numPixels = w * h

    r = 0 | 0
    g = 0 | 0
    b = 0 | 0

    rowBaseIndex = 4 * (frameWidth * t + l) # index of [left, top]
    for row in [0...h] by 1
        pixelIndex = rowBaseIndex + 4 * frameWidth
        for column in [0...w] by 1
            r += frame[pixelIndex] | 0
            g += frame[pixelIndex + 1] | 0
            b += frame[pixelIndex + 2] | 0
            pixelIndex += 4 | 0

    r = roundPositiveNum(r / numPixels)
    g = roundPositiveNum(g / numPixels)
    b = roundPositiveNum(b / numPixels)

    return [
        "rgb(#{r}, #{g}, #{b})"
        (r + g + b) / 3
    ]

pixelateFrameSIMD = (frame, l, t, w, h, frameWidth) -> # left, top, width, height
    # This function avoids calling getImageData() multiple times, which is very slow.
    # This function can safely assume that l + w <= frameWidth; t + h <= frameHeight
    numPixels = w * h

    acc = SIMD.Uint32x4.splat(0)
    current = SIMD.Uint32x4.splat(0)
    rowBaseIndex = 4 * (frameWidth * t + l) # index of [left, top]

    for row in [0...h] by 1
        pixelIndex = rowBaseIndex + 4 * frameWidth

        for column in [0...w] by 1
            current = SIMD.Uint32x4.load3(frame, pixelIndex)
            acc = SIMD.Uint32x4.add(acc, current)
            pixelIndex += 4 | 0

    r = roundPositiveNum(SIMD.Uint32x4.extractLane(acc, 0) / numPixels)
    g = roundPositiveNum(SIMD.Uint32x4.extractLane(acc, 1) / numPixels)
    b = roundPositiveNum(SIMD.Uint32x4.extractLane(acc, 2) / numPixels)

    return [
        "rgb(#{r}, #{g}, #{b})"
        (r + g + b) / 3
    ]

useSIMD = SIMD?

addPixelate = (obj, fillStyle, text, h, v) ->
    # Add everything needed for painting a frame to an object.
    # This object is later handed to paintFrame.
    value = obj[fillStyle]
    if value
        value.push(text, h, v)
        obj[fillStyle] = value
    else
        obj[fillStyle] = new Array(text, h, v)
    null

characterizeFrame = (pixelateFn, frame, frameWidth, frameHeight, option) ->
    numHorizontalSamples = ceilPositiveNum(frameWidth / option.horizontal_sample_rate)
    numVerticalSamples = ceilPositiveNum(frameHeight / option.vertical_sample_rate)

    pixelates = new Object(null)

    for h in [0...numHorizontalSamples] by 1
        areaLeft = h * option.horizontal_sample_rate

        if h is numHorizontalSamples - 1 # last column
            areaWidth = frameWidth - areaLeft
        else
            areaWidth = option.horizontal_sample_rate

        for v in [0...numVerticalSamples] by 1
            areaTop = v * option.vertical_sample_rate

            if v is numVerticalSamples - 1 # last row
                areaHeight = frameHeight - areaTop
            else
                areaHeight = option.vertical_sample_rate

            pixelate = pixelateFn(frame, areaLeft, areaTop, areaWidth, areaHeight, frameWidth)

            fillStyle = pixelate[0]
            if option.use_character
                if option.character_color
                    fillStyle = option.character_color
                text = option.character_set[floorPositiveNum(pixelate[1] / (256 / option.character_set.length))]
                addPixelate(pixelates, fillStyle, text, h, v)
            else
                addPixelate(pixelates, fillStyle, null, h, v)

    return pixelates

onmessage = (msg) ->
    data = msg.data

    if useSIMD
        pixelateFn = pixelateFrameSIMD
        frame = new Uint32Array(data.frame)
    else
        pixelateFn = pixelateFrame
        frame = data.frame

    result = characterizeFrame(
        pixelateFn, frame, data.frameWidth, data.frameHeight,
        data.option
    )
    postMessage(result)
