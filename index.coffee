fs = require 'fs'
vm = require 'vm'
fetch = require 'node-fetch'
{toDate} = require 'date-fns-tz'
CoffeeScript = require 'coffeescript'
EJSON = require 'ejson'

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
  longestName: ->
    (@names().sort (x, y) -> y.length - x.length)[0]

processLogs = (logs, start, end, rooms) ->
  users = {}
  elapse = (user, upto) ->
    return unless user.last?
    elapsed = upto.getTime() - user.last.getTime()
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
  for id, user of users
    console.log "#{if user.admin then '@' else ' '}#{user.longestName() or '?'} [#{id}]: #{formatTimeAmount user.time.inRoom} <= #{formatTimeAmount user.time.inMeeting}"

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
  query =
    meeting: config.meeting
    secret: config.secret
  rooms = {}
  for event in config.events
    start = toDate event.start, timeZone: config.timezone
    end = toDate event.end, timeZone: config.timezone
    response = await api config.server, 'log/get', Object.assign {}, query,
      {start, end}
    unless response.ok
      console.warn "Failed to load event '#{event.title}': #{response.error}"
      continue
    processLogs response.logs, start, end, rooms
  console.log 'ROOMS'
  response = await api config.server, 'room/get', Object.assign {}, query,
    rooms: (id for id of rooms)
  unless response.ok
    return console.warn "Failed to load rooms"
  for room in response.rooms
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
