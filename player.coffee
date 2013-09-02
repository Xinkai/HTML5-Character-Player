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
    constructor: (@np, @ap, options, onFpsUpdate) ->
        # for RequestAnimationFrame
        @requestId = null
        @framePainted = null
        @fpsIntervalId = null
        @fpsUpdateRate = 250
        # options
        @option = options

        # snapshoting native player into a canvas for every frame
        @sn = document.createElement("canvas")
        @snContext = @sn.getContext("2d")

        @apContext = @ap.getContext("2d")
        @apContext.font = "5px"

        @np.addEventListener "playing", () =>
            @onPause()
            @fpsIntervalId = setInterval( () =>
                onFpsUpdate @framePainted / (@fpsUpdateRate / 1000)
                @framePainted = 0
            , @fpsUpdateRate)
            @requestId = requestAnimationFrame(@nextFrame)

        @np.addEventListener "pause", @onPause

        @np.addEventListener("canplay", () =>
            @sn.width = @np.videoWidth
            @sn.height = @np.videoHeight
        )

        document.addEventListener("fullscreenchange", @onFullscreenChange)
        document.addEventListener("webkitfullscreenchange", @onFullscreenChange)
        document.addEventListener("mozfullscreenchange", @onFullscreenChange)
        document.addEventListener("MSFullscreenChange", @onFullscreenChange)

    onPause: () =>
        if @requestId
            cancelAnimationFrame(@requestId)
        if @fpsIntervalId
            clearInterval(@fpsIntervalId)
        @framePainted = 0

    nextFrame: () =>
        # snapshot
        @snContext.drawImage(@np, 0, 0, @np.videoWidth, @np.videoHeight)

        # clean canvas
        @apContext.fillStyle = "white"
        @apContext.fillRect(0, 0, @ap.width, @ap.height)

        numHorizontalSamples = Math.round(@np.videoWidth / @option.horizontal_sample_rate)
        numVerticalSamples = Math.round(@np.videoHeight / @option.vertical_sample_rate)

        pixelates = new Object(null)
        # pixelates = {
        #    [fillStyle]: [h1, v1, text], [h2, v2]
        # }

        for h in [0...numHorizontalSamples] by 1
            for v in [0...numVerticalSamples] by 1
                areaPixelArray = @snContext.getImageData(
                    h * @option.horizontal_sample_rate, v * @option.vertical_sample_rate,
                    @option.horizontal_sample_rate, @option.vertical_sample_rate
                )
                pixelate = @pixelateArea(areaPixelArray.data)

                fillStyle = pixelate[0]
                if @option.use_character
                    if @option.force_black
                        fillStyle = "black"
                    text = @option.character_set[Math.floor(pixelate[1] / (256 / @option.character_set.length))]
                    addPixelate(pixelates, fillStyle, text, h, v)
                else
                    addPixelate(pixelates, fillStyle, null, h, v)

        @paintFrame(pixelates)
        @framePainted++
        @requestId = requestAnimationFrame(@nextFrame)
        null

    paintFrame: (pixelates) ->
        for fillStyle, details of pixelates
            @apContext.fillStyle = fillStyle
            for i in [0...details.length] by 3
                if @option.use_character
                    @apContext.fillText(details[i],
                                        details[i+1] * @option.horizontal_sample_rate,
                                        details[i+2] * @option.vertical_sample_rate)
                else
                    @apContext.fillRect(details[i+1] * @option.horizontal_sample_rate,
                                        details[i+2] * @option.vertical_sample_rate,
                                        @option.horizontal_sample_rate,
                                        @option.vertical_sample_rate)
        null

    setOption: (options) ->
        for key, value of options
            @option[key] = value

    open: (file) ->
        try
            @np.src = file
        catch error
            alert error
            return false

    requestFullScreen: () =>
        if "requestFullscreen" of @ap # standard treats fullscreen as one word.
            @ap.requestFullscreen()
        else if "webkitRequestFullScreen" of @ap # Chrome support both!!
            @ap.webkitRequestFullScreen()
        else if "webkitRequestFullscreen" of @ap
            @ap.webbkitRequestscreen()
        else if "mozRequestFullScreen" of @ap # Firefox
            @ap.mozRequestFullScreen()
        else if "msRequestFullscreen" of @ap # IE treats fullscreen as one word. ^_^
            @ap.msRequestFullscreen()
        else
            return false
        return true

    onFullscreenChange: (event) =>
        if document.isFullscreen
            @ap.old_width = @ap.width
            @ap.old_height = @ap.height
            @ap.width = window.screen.width
            @ap.height = window.screen.height
            @apContext.save()
            @apContext.scale(@ap.width / @np.videoWidth, @ap.height / @np.videoHeight)
            console.log "enter fullscreen"
        else
            @ap.width = @ap.old_width
            @ap.height = @ap.old_height
            @apContext.restore()
            console.log "exit fullscreen"

    pixelateArea: (pixelArrayData) ->
        # return [rgb_css_str, greyscale]
        numPixels = pixelArrayData.length / 4

        r = 0
        g = 0
        b = 0

        for i in [0...pixelArrayData.length] by 4
            r += pixelArrayData[i]
            g += pixelArrayData[i + 1]
            b += pixelArrayData[i + 2]

        r = Math.round(r / numPixels)
        g = Math.round(g / numPixels)
        b = Math.round(b / numPixels)

        return [
            "rgb(#{r}, #{g}, #{b})"
            (r + g + b) / 3
        ]

window.CharacterPlayer = CharacterPlayer