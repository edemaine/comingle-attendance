fs = require 'fs'
vm = require 'vm'
fetch = require 'node-fetch'
add = require 'date-fns/add'
sub = require 'date-fns/sub'
{toDate} = require 'date-fns-tz'
CoffeeScript = require 'coffeescript'
EJSON = require 'ejson'

defaultEarly = '4h5m'

## Parse duration of the form "+1d-2h+3m-4s"
##                         or "+1 day - 2 hours + 3 minutes - 4 seconds"
parseDuration = (t) ->
  duration =
    days: 0
    hours: 0
    minutes: 0
    seconds: 0
  re = ///
    (
      (?:[-+]\s*)?  # optional sign
      \d+           # integer
    ) \s*
    ([dhms])        # days/hours/minutes/seconds
  ///g
  while (match = re.exec t)?
    for key of duration
      if key.startsWith match[2]
        duration[key] += parseInt match[1]
        break
  duration

## Convert a number of milliseconds into a number of hours, minutes, and seconds
formatTimeAmount = (t) ->
  t = Math.round t / 1000  # convert to seconds
  seconds = t % 60
  t = Math.floor t / 60
  minutes = t % 60
  t = Math.floor t / 60
  hours = t
  "#{hours}h #{minutes}m #{seconds}s"

lastname = (name) ->
  ## Sorting by last name, from Coauthor/Comingle
  space = name.lastIndexOf ' '
  (if space >= 0
    name[space+1..] + ", " + name[...space]
  else
    name
  ).toLowerCase()
sortNames = (items, sort, item2name = (x) -> x) ->
  switch sort
    when 'lastname'
      nameSortKey = lastname
    else
      nameSortKey = (name) -> name.toLowerCase()
  items.sort (x, y) ->
    x = nameSortKey item2name x
    y = nameSortKey item2name y
    if x < y
      -1
    else if x > y
      +1
    else
      0

applyCheck = (check, target, toString, inverted) ->
  if check.constructor.name == 'RegExp'
    check.test toString target
  else if check instanceof Function
    check target
  else if typeof check == 'string'
    check == toString target
  else if Array.isArray check
    if inverted
      check.some (part) -> applyCheck part, target, toString
    else
      check.every (part) -> applyCheck part, target, toString
  else
    console.error "Invalid filter #{check}"

applyFilter = (list, filter, toString) ->
  return unless filter?
  return unless filter.exclude? or filter.include?
  for key of filter
    switch key
      when 'exclude'
        oldList = list
        list = list.filter (item) ->
          not applyCheck filter.exclude, item, toString, true
      when 'include'
        list = list.filter (item) ->
          applyCheck filter.include, item, toString
  list

class User
  constructor: (id) ->
    if id?
      @ids = [id]      # list of presence IDs used by this user
    else
      @ids = []
    @admin = false     # was this user ever an admin?
    @nameMap = {}      # keys store the actual used names
    @activeId = {}     # keys are presence IDs that are currently active
    @last = undefined  # Date of last presence event, if currently active
    @rooms = {}        # map from ID to array of rooms currently in
    @time =
      inMeeting: 0
      inRoom: 0
      inCompany: 0
  names: ->
    name for name of @nameMap
  name: ->
    ## Choose longest name as canonical, and remove some parentheticals
    (@names().sort (x, y) -> y.length - x.length)[0]
    ?.replace ///\s*\( (TA|\u03a4\u0391|LA|he/him|she/her|) \)\s*///g, ''
    ?.replace /\\/g, ''  # common typo, I guess because near enter key
    ?.trim()
  uniqueRooms: ->
    roomMap = {}
    for id, rooms of @rooms
      roomMap[room] = true for room in rooms
    Object.keys roomMap
  active: ->
    return true for id of @activeId
    false
  consume: (other) ->
    @admin or= other.admin
    @nameMap[name] = true for name of other.nameMap
    @ids.push ...other.ids
    @activeId[id] = true for id of other.activeId
    for own key of other.time
      @time[key] += other.time[key]

class Room
  constructor: (data) ->
    @[key] = value for key, value of data when key not in ['joined']
    @total =
      occupied: 0
    @time = {}
    @row = {}
    @reset()
  reset: ->
    for key of @total
      @total[key] += @time[key] if @time[key]?
      @time[key] = 0
    @joinedIds = {}
  joined: ->
    Object.keys @joinedIds

processLogs = (logs, start, end, rooms, config) ->
  room.reset() for id, room of rooms
  ## In first pass through the logs, find used names for each presence ID,
  ## and detect whether their first log message isn't a join (so they should be
  ## considered active at the start).
  users = {}
  for log in logs
    continue unless log.type.startsWith 'presence'
    unless (user = users[log.id])?
      user = users[log.id] = new User log.id
      user.activeId[log.id] = true unless log.type == 'presenceJoin'
    user.nameMap[log.name] = true if log.name?

  ## Merge together users with the same name (assuming they are the
  ## same people just from different tabs), except for blanks (?).
  nameMap = {}
  for id, user of users
    name = user.name() or '?'
    name = name.toLowerCase()
    (nameMap[name] ?= []).push user
  uniqueUsers = {}
  uniqueUsers['?'] = new User if nameMap['?']?  # put at top of ordering
  for name in sortNames Object.keys(nameMap), config.sort
    continue if name == '?'
    usersWithName = nameMap[name]
    user = usersWithName.shift()
    uniqueUsers[user.name()] = user
    ## Combine all other users with the same name into `user`
    for other in usersWithName
      user.consume other
      users[other.ids[0]] = user

  ## Simulate empty join at start time if first event isn't join for some ID
  for id, user of users
    user.last = start if user.active()

  ## In second pass through the logs, run discrete event simulation and log
  ## total time that users are active and/or in rooms, as well as room times.
  startTime = start.getTime()
  elapse = (user, upto) ->
    return unless user.last?
    elapsed = upto.getTime() - Math.max startTime, user.last.getTime()
    return unless elapsed > 0
    user.time.inMeeting += elapsed
    userRooms = user.uniqueRooms()
    userRooms = applyFilter userRooms, config.inRoom, (room) ->
      rooms[room]?.title ? room
    if userRooms.length
      user.time.inRoom += elapsed
      if (userRooms.some (room) ->
            rooms[room]?.joined().some (other) ->
              other not in user.ids)
        user.time.inCompany += elapsed
    for room in userRooms
      rooms[room] ?= new Room
        _id: room
        title: 'INVALID ROOM'
      rooms[room].time.occupied += elapsed
    undefined
  for log in logs
    continue unless log.type.startsWith 'presence'
    user = users[log.id]
    ## Mark a user as admin if they were ever an admin
    user.admin or= log.admin if log.admin?
    ## Measure presence time
    elapse user, log.updated
    ## Update user for next log event
    if log.type == 'presenceLeave'
      delete user.activeId[log.id]
      for room in user.rooms[log.id] ? []
        delete rooms[room]?.joinedIds[log.id]
      delete user.rooms[log.id]
    else
      user.activeId[log.id] = true
      if log.rooms?.joined?
        for room in user.rooms[log.id] ? []
          delete rooms[room]?.joinedIds[log.id]
        user.rooms[log.id] = log.rooms.joined
        for room in user.rooms[log.id]
          rooms[room]?.joinedIds[log.id] = true
    if user.active()
      user.last = log.updated
    else
      user.last = undefined
  ## End of logs, but measure presence time for any users still joined
  for name, user of uniqueUsers
    elapse user, end

  ## Create "unknown" user that sums all '?' users
  for user in nameMap['?'] ? []
    uniqueUsers['?'].consume user

  ## Output
  for name, user of uniqueUsers
    {admin, time} = user
    console.log "#{if admin then '@' else ' '}#{name}: " +
      "#{formatTimeAmount time.inCompany} in company, " +
      "#{formatTimeAmount time.inRoom} in room, " +
      "#{formatTimeAmount time.inMeeting} in meeting"
    {name, admin, time}

api = (server, op, query) ->
  url = server
  url += '/' unless url.endsWith '/'
  url += "api/#{op}"
  response = await fetch url,
    method: 'POST'
    body: EJSON.stringify query
    headers: 'Content-Type': 'application/json'
  response = await response.text()
  EJSON.parse response

run = (config) ->
  unless config.server
    return console.error "Config file needs key server: https://..."
  unless config.meeting
    return console.error "Config file needs key meeting: abc..."
  unless config.secret
    return console.error "Config file needs key secret: abc..."
  early = parseDuration config.early ? defaultEarly
  query =
    meeting: config.meeting
    secret: config.secret
  ## Load data for rooms in meeting
  rooms = {}
  response = await api config.server, 'room/get', query
  unless response.ok
    return console.warn "Failed to load rooms"
  for room in response.rooms
    rooms[room._id] = new Room room
  ## Load and process logs
  users = {}
  for event, index in config.events
    start = toDate event.start, timeZone: config.timezone
    start = add start, parseDuration config.adjust.start if config.adjust?.start?
    end = toDate event.end, timeZone: config.timezone
    end = add end, parseDuration config.adjust.end if config.adjust?.end?
    console.log '>', event.title, start, end
    response = await api config.server, 'log/get', Object.assign {}, query,
      start: sub start, early
      end: end
    unless response.ok
      console.warn "Failed to load event '#{event.title}': #{response.error}"
      continue
    eventUsers = processLogs response.logs, start, end, rooms, config
    for user in eventUsers
      name = user.name.toLowerCase()
      users[name] ?=
        name: user.name
        row: {}
      users[name].admin or= user.admin
      for key, value of user.time
        users[name].row[key] ?= []
        users[name].row[key][index] = value
    for id, room of rooms
      for key, value of room.time
        room.row[key] ?= []
        room.row[key][index] = value
  ## Write TSV files
  formatAsMinutes = (time) ->
    if time?
      (time / 1000 / 60)  # minutes
      .toFixed config.precision ? 0
    else
      ''
  for output in config.output ? []
    table = [
      (if output.user?
        ['Admin', 'Name', 'Total']
      else if output.room?
        ['ID', 'Title', 'Total']
      ).concat (
        for event, index in config.events
          event.title ? index.toString()
      )
    ]
    if output.user?
      for name in sortNames Object.keys(users), output.sort ? config.sort
        user = users[name]
        total = 0
        total += time for time in user.row[output.user] when time?
        table.push [
          if user.admin then '@' else ''
          user.name
          formatAsMinutes total
        ].concat (
          for time in user.row[output.user]
            formatAsMinutes time
        )
    else if output.room?
      for room in Object.values(rooms).sort (x, y) -> y.total[output.room] - x.total[output.room]
        table.push [
          room._id
          room.title
          formatAsMinutes room.total[output.room]
        ].concat (
          for time in room.row[output.room]
            formatAsMinutes time
        )
    table.push []  # add terminating newline
    fs.writeFileSync output.tsv,
      (row.join '\t' for row in table).join '\n'
  ## Room stats
  console.log '> ROOMS'
  sortedRooms = Object.values rooms
  .sort (x, y) -> y.total.occupied - x.total.occupied
  for room in sortedRooms
    console.log "#{room.title} [#{room._id}]: #{formatTimeAmount room.time.occupied}"

readConfig = (filename) ->
  console.log '*', filename
  js = fs.readFileSync filename, encoding: 'utf8'
  if filename.endsWith '.coffee'
    js = CoffeeScript.compile js,
      bare: true
      filename: filename
      inlineMap: true
  vm.runInNewContext js, undefined, {filename}

main = ->
  unless process.argv.length > 2
    console.error "usage: #{process.argv[0]} #{process.argv[1]} config.{js,coffee}"
    return
  for arg in process.argv[2..]
    await run readConfig arg

module.exports = {defaultEarly, parseDuration, formatTimeAmount, lastname, sortNames, api, run, readConfig, main}

main() if require.main == module
