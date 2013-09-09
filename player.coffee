"use strict"

###
Copyright (c) 2013 Xinkai Chen.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
###

# Compatibility work
if "isFullscreen" not of document
    Object.defineProperty(document, "isFullscreen", {
        get: () ->
            if "webkitIsFullScreen" of document
                return document.webkitIsFullScreen
            else if "mozFullScreen" of document
                return document.mozFullScreen
            else if "msFullscreenElement" of document
                return document.msFullscreenElement isnt null
            else
                console.log "no support for isFullscreen"
                return false
    })

# Utilities
floorPositiveNum = (num) ->
    num | 0

roundPositiveNum = (num) ->
    (.5 + num) | 0

ceilPositiveNum = (num) ->
    tmp = num | 0
    if tmp is num
        return tmp
    else
        return tmp + 1

min = (a, b) ->
    if a < b
        return a
    else return b

pixelateFrameData = (frameData, l, t, w, h) -> # left, top, width, height
    # This function avoids calling getImageData() multiple times, which is very slow.
    # This function can safely assume that l + w <= frameData.width; t + h <= frameData.height
    data = frameData.data
    numPixels = w * h

    r = 0
    g = 0
    b = 0

    rowBaseIndex = 4 * (frameData.width * t + l) # index of [left, top]
    for row in [0...h] by 1
        pixelIndex = rowBaseIndex + 4 * frameData.width
        for column in [0...w] by 1
            r += data[pixelIndex]
            g += data[pixelIndex + 1]
            b += data[pixelIndex + 2]
            pixelIndex += 4

    r = roundPositiveNum(r / numPixels)
    g = roundPositiveNum(g / numPixels)
    b = roundPositiveNum(b / numPixels)

    return [
        "rgb(#{r}, #{g}, #{b})"
        (r + g + b) / 3
    ]

addPixelate = (obj, fillStyle, text, h, v) ->
    # Add everything needed for painting a frame to an object.
    # This object is later handed to paintFrame.
    value = obj[fillStyle]
    if value
        value.push(text, h, v)
        obj[fillStyle] = value
    else
        obj[fillStyle] = new Array(text, h, v)

class CharacterPlayer
    constructor: (@np, @cp, @option, onFpsUpdate) ->
        # for RequestAnimationFrame
        @requestId = null

        # for FPS
        @numFramePainted = null
        @fpsIntervalId = null
        @fpsUpdateRate = 250

        # snapshoting native player into a canvas for every frame
        @sn = document.createElement("canvas")
        @snContext = @sn.getContext("2d")

        @cpContext = @cp.getContext("2d")

        @np.addEventListener "playing", () =>
            @onPause()
            @fpsIntervalId = setInterval( () =>
                onFpsUpdate @numFramePainted / (@fpsUpdateRate / 1000)
                @numFramePainted = 0
            , @fpsUpdateRate)
            @requestId = requestAnimationFrame(@nextFrame)

        @np.addEventListener "pause", @onPause

        @np.addEventListener("canplay", () =>
            ratio_width = @option.max_width / @np.videoWidth
            ratio_height = @option.max_height / @np.videoHeight

            snapshotRatio = min(ratio_width, ratio_height)

            @sn.width = @np.videoWidth * snapshotRatio
            @sn.height = @np.videoHeight * snapshotRatio
            @snContext.scale(snapshotRatio, snapshotRatio)

            @cp.width = @sn.width
            @cp.height = @sn.height

            # otherwise clearRect() causes black background
            @cp.style.backgroundColor = "white"

            # canvas size change causes text align error
            @onCharacterSettingChange()
        )

        document.addEventListener("fullscreenchange", @onFullscreenChange)
        document.addEventListener("webkitfullscreenchange", @onFullscreenChange)
        document.addEventListener("mozfullscreenchange", @onFullscreenChange)
        document.addEventListener("MSFullscreenChange", @onFullscreenChange)

    onCharacterSettingChange: () =>
        # every time canvas resizes, text alignments reset, at least on Chrome
        @cpContext.textBaseline = "top"
        @cpContext.textAlign = "left"

        # text align change causes font size change
        @cpContext.font = @option.character_font_size + " sans-serif"

    onPause: () =>
        if @requestId
            cancelAnimationFrame(@requestId)
        if @fpsIntervalId
            clearInterval(@fpsIntervalId)
        @numFramePainted = 0

    nextFrame: () =>
        # snapshot
        @snContext.drawImage(@np, 0, 0, @np.videoWidth, @np.videoHeight)
        frameData = @snContext.getImageData(0, 0, @sn.width, @sn.height)

        # clear canvas
        @cpContext.clearRect(0, 0, @cp.width, @cp.height)

        numHorizontalSamples = ceilPositiveNum(@sn.width / @option.horizontal_sample_rate)
        numVerticalSamples = ceilPositiveNum(@sn.height / @option.vertical_sample_rate)

        pixelates = new Object(null)
        # pixelates = {
        #    [fillStyle]: [text, h1, v1], [null, h2, v2]
        # }

        for h in [0...numHorizontalSamples] by 1
            areaLeft = h * @option.horizontal_sample_rate

            if h is numHorizontalSamples - 1 # last column
                areaWidth = @sn.width - areaLeft
            else
                areaWidth = @option.horizontal_sample_rate

            for v in [0...numVerticalSamples] by 1
                areaTop = v * @option.vertical_sample_rate

                if v is numVerticalSamples - 1 # last row
                    areaHeight = @sn.height - areaTop
                else
                    areaHeight = @option.vertical_sample_rate

                pixelate = pixelateFrameData(frameData, areaLeft, areaTop, areaWidth, areaHeight)

                fillStyle = pixelate[0]
                if @option.use_character
                    if @option.character_color
                        fillStyle = @option.character_color
                    text = @option.character_set[floorPositiveNum(pixelate[1] / (256 / @option.character_set.length))]
                    addPixelate(pixelates, fillStyle, text, h, v)
                else
                    addPixelate(pixelates, fillStyle, null, h, v)

        @paintFrame(pixelates)
        @numFramePainted++
        @requestId = requestAnimationFrame(@nextFrame)
        null

    paintFrame: (pixelates) ->
        for fillStyle, details of pixelates
            @cpContext.fillStyle = fillStyle
            for i in [0...details.length] by 3
                if @option.use_character
                    @cpContext.fillText(details[i],
                                        details[i+1] * @option.horizontal_sample_rate,
                                        details[i+2] * @option.vertical_sample_rate)
                else
                    @cpContext.fillRect(details[i+1] * @option.horizontal_sample_rate,
                                        details[i+2] * @option.vertical_sample_rate,
                                        @option.horizontal_sample_rate,
                                        @option.vertical_sample_rate)
        null

    setOption: (options) ->
        for key, value of options
            @option[key] = value
            if key is "character_font_size"
                @onCharacterSettingChange()

    open: (file) ->
        try
            @np.src = file
        catch error
            alert error
            return false

    requestFullScreen: () =>
        if "requestFullscreen" of @cp # standard treats fullscreen as one word.
            @cp.requestFullscreen()
        else if "webkitRequestFullScreen" of @cp # Chrome support both!!
            @cp.webkitRequestFullScreen()
        else if "webkitRequestFullscreen" of @cp
            @cp.webbkitRequestscreen()
        else if "mozRequestFullScreen" of @cp # Firefox
            @cp.mozRequestFullScreen()
        else if "msRequestFullscreen" of @cp # IE treats fullscreen as one word. ^_^
            @cp.msRequestFullscreen()
        else
            return false
        return true

    onFullscreenChange: (event) =>
        if document.isFullscreen
            @cp.old_width = @cp.width
            @cp.old_height = @cp.height

            fsRatio_width = screen.width / @cp.old_width
            fsRatio_height = screen.height / @cp.old_height
            fsRatio = min(fsRatio_width, fsRatio_height)

            @cp.width = @cp.old_width * fsRatio
            @cp.height = @cp.old_height * fsRatio

            @cpContext.save()
            @cpContext.scale(fsRatio, fsRatio)
            console.log "enter fullscreen"
        else
            @cp.width = @cp.old_width
            @cp.height = @cp.old_height
            @cpContext.restore()
            console.log "exit fullscreen"
        @onCharacterSettingChange()

window.CharacterPlayer = CharacterPlayer