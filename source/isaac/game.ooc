
// third-party stuff
use dye
import dye/[core, loop, input, primitives, math, sprite, text]

use deadlogger
import deadlogger/[Log, Logger]

use gnaar
import gnaar/[grid, utils]

// sdk stuff
import math/Random

// our stuff
import isaac/[logging, level, bomb, hero]

/*
 * The game, duh.
 */
Game: class {

    dye: DyeContext
    scene: Scene

    loop: FixedLoop

    uiGroup, mapGroup, levelGroup: GlGroup

    level: Level

    logger := static Log getLogger(This name)

    FONT := "assets/ttf/8-bit-wonder.ttf"

    map: Map

    coinLabel, bombLabel, keyLabel: GlText

    coinCount := 25
    bombCount := 10
    keyCount := 5

    // state stuff
    state := GameState PLAY
    changeRoomDir := Direction UP
    changeRoomIncr := 30.0

    init: func {
        Logging setup()

        dye = DyeContext new(800, 600, "Paper Isaac")
        dye setClearColor(Color white())

        scene = dye currentScene

        initEvents()
        initGfx()
        initUI()
        initMap()
        initLevel()

        loop = FixedLoop new(dye, 60.0)
        loop run(||
            update()
        )
    }

    initEvents: func {
        scene input onKeyPress(KeyCode ESC, |kp|
            quit()
        )

        scene input onKeyPress(KeyCode E, |kp|
            dropBomb()
        )
    }

    dropBomb: func {
        if (bombCount <= 0) return

        level add(Bomb new(level, level hero pos))
        bombCount -= 1
    }

    changeRoom: func (=changeRoomDir) {
        state = GameState CHANGEROOM
    }

    initUI: func {
        uiGroup = GlGroup new()
        scene add(uiGroup)

        uiBg := GlRectangle new(vec2(800, 100))
        uiBg center = false
        uiBg pos set!(0, 500)
        uiBg color set!(Color new(20, 20, 20))
        uiGroup add(uiBg)

        labelLeft := 350
        labelBottom := 500
        labelFontSize := 18
        labelPadding := 28

        coinLabel = GlText new(FONT, "*00", labelFontSize)
        coinLabel pos set!(labelLeft, labelBottom + labelPadding * 2)
        coinLabel color set!(Color white())
        uiGroup add(coinLabel)

        bombLabel = GlText new(FONT, "*01", labelFontSize)
        bombLabel pos set!(labelLeft, labelBottom + labelPadding)
        bombLabel color set!(Color white())
        uiGroup add(bombLabel)

        keyLabel = GlText new(FONT, "*03", labelFontSize)
        keyLabel pos set!(labelLeft, labelBottom)
        keyLabel color set!(Color white())
        uiGroup add(keyLabel)

        iconLeft := 330
        iconBottom := 528
        iconPadding := labelPadding

        coinIcon := GlSprite new("assets/png/mini-coin.png")
        coinIcon pos set!(iconLeft, iconBottom + iconPadding * 2)
        uiGroup add(coinIcon)

        bombIcon := GlSprite new("assets/png/mini-bomb.png")
        bombIcon pos set!(iconLeft, iconBottom + iconPadding)
        uiGroup add(bombIcon)

        keyIcon := GlSprite new("assets/png/mini-key.png")
        keyIcon pos set!(iconLeft, iconBottom)
        uiGroup add(keyIcon)

        mapGroup = GlGroup new()
        uiGroup add(mapGroup)
    }

    initLevel: func {
        level = Level new(this)
        levelGroup add(level group)
    }

    initGfx: func {
        levelGroup = GlGroup new()
        scene add(levelGroup)

        bgGroup := GlGroup new()
        levelGroup add(bgGroup)
       
        fullBg := GlRectangle new(vec2(800, 500)) 
        fullBg center = false
        fullBg pos set!(0, 0)
        fullBg color set!(Color new(200, 200, 200))
        bgGroup add(fullBg)
       
        arenaBg := GlRectangle new(vec2(650, 350)) 
        arenaBg center = false
        arenaBg pos set!(75, 75)
        arenaBg color set!(Color new(230, 230, 230))
        bgGroup add(arenaBg)

    }

    initMap: func {
        map = Map new(this)
    }

    update: func {
        match state {
            case GameState PLAY =>
                level update()
                updateLabels()

            case GameState CHANGEROOM =>
                updateChangeRoom()
        }
    }

    updateChangeRoom: func {
        finished := false

        match changeRoomDir {
            case Direction UP =>
                levelGroup pos y -= changeRoomIncr
                finished = levelGroup pos y < -400
            case Direction DOWN =>
                levelGroup pos y += changeRoomIncr
                finished = levelGroup pos y > 400
            case Direction LEFT =>
                levelGroup pos x += changeRoomIncr
                finished = levelGroup pos x > 800
            case Direction RIGHT =>
                levelGroup pos x -= changeRoomIncr
                finished = levelGroup pos x < -800
        }

        if (finished) {
            finalizeChangeRoom()
        }
    }

    changeRoomDelta: func -> Vec2i {
        levelGroup pos set!(0, 0)

        match changeRoomDir {
            case Direction UP    => vec2i(0, 1)
            case Direction DOWN  => vec2i(0, -1)
            case Direction LEFT  => vec2i(-1, 0)
            case Direction RIGHT => vec2i(1, 0)
        }
    }

    finalizeChangeRoom: func {
        delta := changeRoomDelta()
        newPos := map currentTile pos add(delta)
        map currentTile = map grid get(newPos x, newPos y)
        map setup()
        level reload(changeRoomDir)

        state = GameState PLAY
    }

    updateLabels: func {
        coinLabel value = "*%02d" format(coinCount)
        bombLabel value = "*%02d" format(bombCount)
        keyLabel value = "*%02d" format(keyCount)
    }

    quit: func {
        dye quit()
        exit(0)
    }

}

/*
 * The mini-map, and, incidently, what holds
 * information about the current floor
 */
Map: class {
    game: Game
    screenSize := vec2(250, 85)
    offset := vec2(20, 505)

    grid := SparseGrid<MapTile> new()

    group: GlGroup

    currentTile: MapTile

    mapSize: Vec2i

    init: func (=game) {
        generate()

        group = GlGroup new()

        bg := GlRectangle new(screenSize)
        bg center = false
        bg pos set!(offset)
        grayShade := 50
        bg color set!(Color new(grayShade, grayShade, grayShade)) 
        game mapGroup add(bg)

        game mapGroup add(group)

        setup()
    }

    generate: func {
        pos := vec2i(0, 0)
        currentTile = add(pos)
        currentTile active = true

        for (i in 0..12) {
            length := Random randInt(1, 5)
            dir := Random randInt(0, 3)
            diff := vec2i(0, 0)

            match dir {
                case 0 => diff x = 1
                case 1 => diff x = -1
                case 2 => diff y = 1
                case 3 => diff y = -1
            }
            "dir = %d, diff = %s, length = %d" printfln(dir, diff _, length)

            mypos := vec2i(pos)
            for (j in 0..length) {
                mypos add!(diff)
                add(mypos)

                if (Random randInt(0, 8) < 5) {
                    pos set!(mypos)
                }
            }
        }

        bounds := grid getBounds()
        mapSize = vec2i(bounds width, bounds height)
        "Generated a map with bounds %s. Size = %dx%d" printfln(bounds _,
            bounds width, bounds height)
    }

    setup: func {
        grid each(|col, row, tile|
            tile reset()
            tile active = (tile == currentTile)
        )

        bounds := grid getBounds()
        gridOffset := vec2i(bounds xMin, bounds yMin)

        gWidth := (bounds width + 1)
        gHeight := (bounds height + 1)

        tileSize := vec2(
            screenSize x / gWidth as Float,
            screenSize y / gHeight as Float
        )

        grid each(|col, row, tile|
            tile setup(col, row, tileSize, gridOffset)
        )
    }
    
    add: func (pos: Vec2i) -> MapTile {
        "Putting map tile at %s" printfln(pos _)
        tile := MapTile new(this, pos)
        grid put(pos x, pos y, tile)
        tile
    }
}

MapTile: class {

    map: Map
    rect: GlMapTile

    pos: Vec2i

    active := false

    init: func (=map, .pos) {
        this pos = vec2i(pos)
    }

    reset: func {
        if (rect) {
            map group remove(rect)            
            rect = null
        }
    }

    setup: func (col, row: Int, tileSize: Vec2, gridOffset: Vec2i) {
        diff := vec2(
            (col - gridOffset x ) * tileSize x,
            (row - gridOffset y ) * tileSize y
        )
        offset := map offset add(diff)
        rect = GlMapTile new(tileSize, active)
        rect setPos(offset)
        map group add(rect)
    }

    hasTop?: func -> Bool {
        hasNeighbor?(0, 1)
    }

    hasBottom?: func -> Bool {
        hasNeighbor?(0, -1)
    }

    hasLeft?: func -> Bool {
        hasNeighbor?(-1, 0)
    }

    hasRight?: func -> Bool {
        hasNeighbor?(1, 0)
    }

    hasNeighbor?: func (col, row: Int) -> Bool {
        map grid contains?(pos x + col, pos y + row)
    }
    
}

GlMapTile: class extends GlGroup {

    outline: GlRectangle
    fill: GlRectangle

    init: func (size: Vec2, active: Bool) {
        super()

        fill = GlRectangle new(size sub(2, 2))
        if (active) {
            fill color set!(Color new(255, 255, 255))
        } else {
            fill color set!(Color new(120, 120, 120))
        }
        fill center = false
        add(fill)

        outline = GlRectangle new(size)
        outline color set!(Color new(10, 10, 10))
        outline lineWidth = 4.0
        outline center = false
        outline filled = false
        add(outline)
    }

    setPos: func (pos: Vec2) {
        fill pos set!(pos)
        outline pos set!(pos)
    }
    
}

GameState: enum {
    PLAY
    CHANGEROOM
}

