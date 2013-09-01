"use strict"

loadPlayer = () ->
    np = document.getElementById("native_player")
    ap = document.getElementById("ascii_player")

    input_pixelate_width = document.getElementById("input_pixelate_width")
    input_pixelate_height = document.getElementById("input_pixelate_height")
    input_character_set = document.getElementById("input_character_set")
    input_use_character = document.getElementById("input_use_character")
    input_force_black = document.getElementById("input_force_black")

    btn_fullscreen = document.getElementById("btn_fullscreen")
    btn_snapshot = document.getElementById("btn_snapshot")

    player = new CharacterPlayer(np, ap, {
        horizontal_sample_rate: input_pixelate_width.value
        vertical_sample_rate: input_pixelate_height.value
        use_character: input_use_character.checked
        character_set: input_character_set.value.split(" ")
        force_black: input_force_black.checked
    })

    onPixelateSizeChange = () ->
        player.setOption
            horizontal_sample_rate: input_pixelate_width.value
            vertical_sample_rate: input_pixelate_height.value

    onCharacterSetChange = () ->
        player.setOption
            character_set: input_character_set.value.split(" ")

    onUseCharacterChange = () ->
        input_character_set.disabled = not input_use_character.checked
        player.setOption
            use_character: input_use_character.checked

    onFileOpen = () ->
        player.open URL.createObjectURL @files[0]

    onForceBlackSet = () ->
        player.setOption
            force_black: input_force_black.checked

    onFullscreenClick = () ->
        player.requestFullScreen()

    onSnapshotClick = () ->
        window.open(ap.toDataURL(), "Snapshot")

    input_pixelate_width.addEventListener("change", onPixelateSizeChange)
    input_pixelate_height.addEventListener("change", onPixelateSizeChange)

    input_character_set.addEventListener("change", onCharacterSetChange)
    input_use_character.addEventListener("change", onUseCharacterChange)
    input_file_open.addEventListener("change", onFileOpen)

    input_force_black.addEventListener("change", onForceBlackSet)
    btn_fullscreen.addEventListener("click", onFullscreenClick)
    btn_snapshot.addEventListener("click", onSnapshotClick)

    # Opening file by Drag-drop
    document.body.addEventListener("dragover", (event) ->
        event.preventDefault()
    )

    np.addEventListener("canplay", () ->
        document.getElementById("video_width").innerHTML = ap.width = np.videoWidth
        document.getElementById("video_height").innerHTML = ap.height = np.videoHeight
        btn_snapshot.disabled = false
    )

    document.body.addEventListener("drop", (event) ->
        event.preventDefault()
        file = event.dataTransfer.files[0]
        player.open URL.createObjectURL file
    )

window.addEventListener("load", loadPlayer)