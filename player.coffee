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

             # Cannot find the implementation about IE and opera
#            else if "msFullscreenEnabled" of document
#                return document.msFullscreenEnabled
#
#            else if "oFullscreenEnabled" of document
#                return document.oFullscreenEnabled
            else
                console.log "no support for fullscreenEnabled"
                return false
    })

class CharacterPlayer
    constructor: (@np, @ap, options) ->
        # for RequestAnimationFrame
        @requestId = null

        # options
        @option = options

        # snapshoting native player into a canvas for every frame
        @sn = document.createElement("canvas")
        @snContext = @sn.getContext("2d")

        @apContext = @ap.getContext("2d")
        @apContext.font = "5px"

        @np.addEventListener "playing", () =>
            @requestId = requestAnimationFrame(@drawFrame)

        @np.addEventListener "pause", () =>
            cancelAnimationFrame(@requestId)

        @np.addEventListener("canplay", () =>
            @sn.width = @np.videoWidth
            @sn.height = @np.videoHeight
        )

        document.addEventListener("webkitfullscreenchange", @onFullscreenChange)
        document.addEventListener("mozfullscreenchange", @onFullscreenChange)
        document.addEventListener("fullscreenchange", @onFullscreenChange)
        document.addEventListener("msfullscreenchange", @onFullscreenChange)
        document.addEventListener("ofullscreenchange", @onFullscreenChange)

    drawFrame: () =>
        # snapshot
        @snContext.drawImage(@np, 0, 0, @np.videoWidth, @np.videoHeight)

        # clean canvas
        @apContext.fillStyle = "white"
        @apContext.fillRect(0, 0, @ap.width, @ap.height)

        for h in [0...Math.round(@np.videoWidth / @option.horizontal_sample_rate)]
            for v in [0...Math.round(@np.videoHeight / @option.vertical_sample_rate)]
                pixelArray = @snContext.getImageData(
                    h * @option.horizontal_sample_rate, v * @option.vertical_sample_rate,
                    @option.horizontal_sample_rate, @option.vertical_sample_rate
                )
                pixelate = @pixelateArea(pixelArray.data)

                @apContext.fillStyle = pixelate[0]

                if @option.use_character
                    if @option.force_black
                        @apContext.fillStyle = "black"
                    text = @option.character_set[Math.floor(pixelate[1] / (256 / @option.character_set.length))]
                    @apContext.fillText(text, h * @option.horizontal_sample_rate, v * @option.vertical_sample_rate)
                else
                    @apContext.fillRect(h * @option.horizontal_sample_rate, v * @option.vertical_sample_rate,
                                        @option.horizontal_sample_rate, @option.vertical_sample_rate)

        @requestId = requestAnimationFrame(@drawFrame)

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
        if "requestFullScreen" of @ap
            @ap.requestFullScreen()
        else if "webkitRequestFullScreen" of @ap
            @ap.webkitRequestFullScreen()
        else if "mozRequestFullScreen" of @ap
            @ap.mozRequestFullScreen()
        # future proof
        else if "msRequestFullScreen" of @ap
            @ap.msRequestFullScreen()
        else if "oRequestFullScreen" of @ap
            @ap.oRequestFullScreen()
        else
            alert "Your browser doesn't support full screen."
            return false

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
        # return [(red, green, black), grayscale]
        numPixels = pixelArrayData.length / 4
        rgb = [0, 0, 0]
        for item, i in pixelArrayData
            m = i % 4
            if m isnt 3
                rgb[m] += item

        for color, i in rgb
            rgb[i] = Math.round(color / numPixels)

        return [
            "rgb(#{rgb.join(', ')})"
            (rgb[0] + rgb[1] + rgb[2]) / 3
        ]
window.CharacterPlayer = CharacterPlayer