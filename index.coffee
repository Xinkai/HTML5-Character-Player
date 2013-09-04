"use strict"

loadPlayer = () ->
    np = document.getElementById("native_player")
    cp = document.getElementById("character_player")

    input_pixelate_width = document.getElementById("input_pixelate_width")
    input_pixelate_height = document.getElementById("input_pixelate_height")
    input_character_set = document.getElementById("input_character_set")
    input_use_character = document.getElementById("input_use_character")
    input_character_font_size = document.getElementById("input_character_font_size")
    input_character_color = document.getElementById("input_character_color")

    btn_fullscreen = document.getElementById("btn_fullscreen")
    btn_snapshot = document.getElementById("btn_snapshot")

    player = new CharacterPlayer(np, cp, {
        horizontal_sample_rate: parseInt input_pixelate_width.value
        vertical_sample_rate: parseInt input_pixelate_height.value
        use_character: input_use_character.checked
        character_set: input_character_set.value.split(" ")
        character_font_size: input_character_font_size.value + "px"
        character_color: input_character_color.value.trim()
        max_width: parseInt(cp.parentNode.clientWidth)
        max_height: parseInt(cp.parentNode.clientHeight)
    }, (fps) ->
        document.getElementById("fps").innerHTML = fps
    )
    # expose this variable for the convenience of debugging
    window.player = player

    onPixelateSizeChange = () ->
        document.getElementById("pixelate_width").innerHTML = input_pixelate_width.value
        document.getElementById("pixelate_height").innerHTML = input_pixelate_height.value
        player.setOption
            horizontal_sample_rate: parseInt input_pixelate_width.value
            vertical_sample_rate: parseInt input_pixelate_height.value

    onCharacterSetChange = () ->
        player.setOption
            character_set: input_character_set.value.split(" ")

    onUseCharacterChange = () ->
        input_character_set.disabled = not input_use_character.checked
        player.setOption
            use_character: input_use_character.checked

    onFileOpen = () ->
        player.open URL.createObjectURL @files[0]

    onCharacterFontSizeSet = () ->
        document.getElementById("character_font_size").innerHTML = input_character_font_size.value
        player.setOption
            character_font_size: input_character_font_size.value + "px"

    onFullscreenClick = () ->
        if not player.requestFullScreen()
            alert "Your browser doesn't support full screen."

    onSnapshotClick = () ->
        window.open(cp.toDataURL(), "Snapshot")

    onCharacterColorSet = () ->
        player.setOption
            character_color: input_character_color.value.trim()

    input_pixelate_width.addEventListener("change", onPixelateSizeChange)
    input_pixelate_height.addEventListener("change", onPixelateSizeChange)

    input_character_set.addEventListener("change", onCharacterSetChange)
    input_use_character.addEventListener("change", onUseCharacterChange)
    input_file_open.addEventListener("change", onFileOpen)

    input_character_font_size.addEventListener("change", onCharacterFontSizeSet)
    input_character_color.addEventListener("change", onCharacterColorSet)

    btn_fullscreen.addEventListener("click", onFullscreenClick)
    btn_snapshot.addEventListener("click", onSnapshotClick)

    # Opening file by Drag-drop
    document.body.addEventListener("dragover", (event) ->
        event.preventDefault()
    )

    np.addEventListener("canplay", () ->
        document.getElementById("status").style.display = "block"
        document.getElementById("video_width").innerHTML = np.videoWidth
        document.getElementById("video_height").innerHTML = np.videoHeight
        btn_snapshot.disabled = false
    )

    document.body.addEventListener("drop", (event) ->
        event.preventDefault()
        file = event.dataTransfer.files[0]
        player.open URL.createObjectURL file
    )

    # initialize
    onPixelateSizeChange()
    onCharacterFontSizeSet()

window.addEventListener("load", loadPlayer)