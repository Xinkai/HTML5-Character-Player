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

min = (a, b) ->
    if a < b
        return a
    else return b

WorkerStatus = {
    Ready: 0
    Working: 1
}

class CharacterPlayer
    constructor: (@np, @cp, @option, onFpsUpdate) ->
        # spawn workers
        @workers = []
        @workerStatus = []
        @concurrency = navigator.hardwareConcurrency
        for i in [0...@concurrency]
            worker = new Worker("worker.js")
            worker.onmessage = @paintFrame
            @workers.push(worker)
            @workerStatus.push(WorkerStatus.Ready)

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
        null

    isAllWorkersReady: () =>
        @workerStatus.every( (one) => one == WorkerStatus.Ready )

    onCharacterSettingChange: () =>
        # every time canvas resizes, text alignments reset, at least on Chrome
        @cpContext.textBaseline = "top"
        @cpContext.textAlign = "left"

        # text align change causes font size change
        @cpContext.font = @option.character_font_size + " sans-serif"
        null

    onPause: () =>
        if @requestId
            cancelAnimationFrame(@requestId)
        if @fpsIntervalId
            clearInterval(@fpsIntervalId)
        @numFramePainted = 0
        null

    nextFrame: () =>
        # snapshot
        if not @isAllWorkersReady()
            return

        @snContext.drawImage(@np, 0, 0, @np.videoWidth, @np.videoHeight)

        sliceHeight = ((@sn.height / @concurrency / @option.vertical_sample_rate) | 0) * @option.vertical_sample_rate

        t = 0
        for pos in [0...@concurrency]
            if pos == @concurrency - 1
                # last one
                h = @sn.height - sliceHeight * pos
            else
                h = sliceHeight

            meta = {
                pos: pos
                sliceHeight: sliceHeight
            }
            frameData = @snContext.getImageData(0, t, @sn.width, h)
            @workers[pos].postMessage({
                frame: frameData.data
                frameHeight: h
                frameWidth: frameData.width
                option: @option
                meta: meta
            }, [frameData.data.buffer])
            @workerStatus[pos] = WorkerStatus.Working
            t += sliceHeight
        null

    paintFrame: (msg) =>
        # receive from workers
        pixelates = msg.data
        sliceHeight = pixelates.meta.sliceHeight
        pos = pixelates.meta.pos

        # clear canvas
        if pos != @concurrency - 1
            @cpContext.clearRect(0, pos * sliceHeight, @cp.width, sliceHeight)
        else
            @cpContext.clearRect(0, pos * sliceHeight, @cp.width, @cp.height - pos * sliceHeight)

        for fillStyle, details of pixelates
            @cpContext.fillStyle = fillStyle
            for i in [0...details.length] by 3
                if @option.use_character
                    @cpContext.fillText(details[i],
                                        details[i+1] * @option.horizontal_sample_rate,
                                        details[i+2] * @option.vertical_sample_rate + pos * sliceHeight)
                else
                    @cpContext.fillRect(details[i+1] * @option.horizontal_sample_rate,
                                        details[i+2] * @option.vertical_sample_rate + pos * sliceHeight,
                                        @option.horizontal_sample_rate,
                                        @option.vertical_sample_rate)

        @workerStatus[pos] = WorkerStatus.Ready
        if @isAllWorkersReady()
            @numFramePainted++
            @requestId = requestAnimationFrame(@nextFrame)
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
        null

window.CharacterPlayer = CharacterPlayer
