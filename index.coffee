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

class User
  constructor: (@id, @last) ->
    @admin = false
    @nameMap = {}
    @last              # last presence event, or undefined if left meeting
    @rooms = []        # rooms currently in
    @time =
      inMeeting: 0
      inRoom: 0
  names: ->
    name for name of @nameMap
  name: ->
    ## Choose longest name as canonical, and remove some parentheticals
    (@names().sort (x, y) -> y.length - x.length)[0]
    ?.replace ///\s*\( (TA|\u03a4\u0391|LA|he/him|she/her|) \)\s*///g, ''
    ?.replace /\\/g, ''  # common typo, I guess because near enter key
    ?.trim()

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

processLogs = (logs, start, end, rooms, config) ->
  users = {}
  startTime = start.getTime()
  elapse = (user, upto) ->
    return unless user.last?
    elapsed = upto.getTime() - Math.max startTime, user.last.getTime()
    return unless elapsed > 0
    user.time.inMeeting += elapsed
    if user.rooms.length
      user.time.inRoom += elapsed
      for room in user.rooms
        rooms[room] ?= 0
        rooms[room] += elapsed
    undefined
  for log in logs
    continue unless log.type.startsWith 'presence'
    user = users[log.id] ?= new User log.id,
      ## Simulate empty join at start time if first event for user isn't join
      (start unless log.type == 'presenceJoin')
    ## Mark a user as admin if they were even an admin
    user.admin or= log.admin if log.admin?
    ## Collect names
    user.nameMap[log.name] = true if log.name?
    ## Measure presence time
    elapse user, log.updated
    ## Update user for next log event
    user.rooms = log.rooms.joined if log.rooms?.joined?
    if log.type == 'presenceLeave'
      user.last = undefined
      user.rooms = []
    else
      user.last = log.updated
  ## End of logs, but measure presence time for any users still joined
  for id, user of users
    elapse user, end
  ## Raw user report from this event
  #for id, user of users
  #  console.log "#{if user.admin then '@' else ' '}#{user.name() or '?'} [#{id}]: #{formatTimeAmount user.time.inRoom} <= #{formatTimeAmount user.time.inMeeting}"
  ## Combine users with same name
  nameMap = {}
  for id, user of users
    name = user.name() or '?'
    (nameMap[name] ?= []).push user
  for name in sortNames (name for own name of nameMap), config.sort
    time = {}
    admin = false
    for user in nameMap[name]
      admin or= user.admin
      for own key of user.time
        time[key] ?= 0
        time[key] += user.time[key]
    console.log "#{if admin then '@' else ' '}#{name}: #{formatTimeAmount time.inRoom} <= #{formatTimeAmount time.inMeeting}"
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
  rooms = {}
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
      unless users[user.name]?
        users[user.name] = []
        users[user.name].name = user.name
      users[user.name].admin or= user.admin
      users[user.name][index] = user.time.inRoom
  ## Write TSV
  if config.tsv?
    table = [
      ['Admin', 'Name'].concat (
        for event, index in config.events
          event.title ? index.toString()
      )
    ]
    for name in sortNames (name for own name of users), config.sort
      user = users[name]
      table.push [
        if user.admin then '@' else ''
        user.name
      ].concat (
        for time in user
          if time?
            (time / 1000 / 60)  # minutes
            .toFixed config.precision ? 0
          else
            ''
      )
    table.push []  # add terminating newline
    fs.writeFileSync config.tsv,
      (row.join '\t' for row in table).join '\n'
  ## Room stats
  console.log '> ROOMS'
  response = await api config.server, 'room/get', Object.assign {}, query,
    rooms: (id for id of rooms)
  unless response.ok
    return console.warn "Failed to load rooms"
  sortedRooms = (room for room in response.rooms when rooms[room._id]?)
  .sort (x, y) -> rooms[y._id] - rooms[x._id]
  for room in sortedRooms
    continue unless rooms[room._id]?
    console.log "#{room.title} [#{room._id}]: #{formatTimeAmount rooms[room._id] ? 0}"

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

main() if require.main == module
