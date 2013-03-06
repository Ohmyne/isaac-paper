
// third-party stuff
use deadlogger
import deadlogger/[Log, Logger]

// sdk stuff
import structs/[ArrayList, List, HashMap]
import io/[FileReader]

Rooms: class {
    sets := HashMap<String, RoomSet> new()

    logger := static Log getLogger(This name)

    init: func {
        load("basement")
        load("cellar")
        load("lust")
        load("treasure")
    }

    load: func (name: String) {
        logger info("Loading set %s", name)
        sets put(name, RoomSet new(name))
    }

}

RoomSet: class {
    name: String
    rooms := ArrayList<Room> new()

    logger := static Log getLogger(This name)

    init: func (=name) {
        read("assets/levels/%s.txt" format(name))
        logger info("Got %d rooms for room set %s", rooms size, name)
    }

    read: func (path: String) {
        lineno := 1

        reader := FileReader new(path)
        room := Room new()

        while (reader hasNext?()) {
            line := reader readLine()
            lineno += 1

            if (line size < 13) {
                if (reader hasNext?()) {
                    continue
                } else {
                    break
                }
            }

            if (line size != 13) {
                _err(path, lineno, "Expected 13 chars, got %d, '%s'" format(line size, line))
            }
            room rows add(line)

            if (room rows size >= 7) {
                line = reader readLine()
                lineno += 1

                if (line != "" && reader hasNext?()) {
                    _err(path, lineno, "Expected empty line, got '%s'" format(line))
                }
                rooms add(room)
                room = Room new()
            }
        }

        if (!rooms contains?(room) && room rows size == 7) {
            rooms add(room)
        }
    }

    _err: func (path: String, lineno: Int, message: String) {
        raise("[RoomSet] %s:%d - %s" format(path, lineno, message))
    }
}

Room: class {
    rows := ArrayList<String> new()

    init: func
}