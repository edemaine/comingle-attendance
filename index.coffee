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
  constructor: ->
    @admin = false
    @nameMap = {}
    @join = undefined
    @present = 0
  names: ->
    name for name of @nameMap
  longestName: ->
    (@names().sort (x, y) -> y.length - x.length)[0]

processLogs = (logs, start, finish) ->
  users = {}
  for log in logs
    continue unless log.type.startsWith 'presence'
    user = users[log.id] ?= new User
    ## Mark a user as admin if they were even an admin
    user.admin or= log.admin if log.admin?
    ## Collect names
    user.nameMap[log.name] = true if log.name?
    ## Measure presence
    if log.type == 'presenceJoin'
      user.join = log.updated
    else
      ## May have missed join before the start time; simulate one then.
      user.join ?= start
    if log.type == 'presenceLeave'
      user.present += log.updated.getTime() - user.join.getTime()
      user.join = undefined
  for id, user of users
    user.present += finish.getTime() - user.join.getTime() if user.join?
  for id, user of users
    console.log "#{if user.admin then '@' else ' '}#{user.longestName() or '?'} [#{id}]: #{formatTimeAmount user.present}"

api = (url, query) ->
  response = await fetch url,
    method: 'POST'
    body: EJSON.stringify query
    headers: 'Content-Type': 'application/json'
  response = await response.text()
  EJSON.parse response

run = (config) ->
  unless config.server
    return console.error "Config file needs key server: https://..."
  url = config.server
  url += '/' unless url.endsWith '/'
  url += 'api/log/get'
  unless config.meeting
    return console.error "Config file needs key meeting: abc..."
  unless config.secret
    return console.error "Config file needs key secret: abc..."
  query =
    meeting: config.meeting
    secret: config.secret
  for event in config.events
    query.start = toDate event.start, timeZone: config.timezone
    query.finish = toDate event.end, timeZone: config.timezone
    response = await api url, query
    unless response.ok
      console.warn "Failed to load event '#{event.title}': #{response.error}"
      continue
    processLogs response.logs, query.start, query.finish

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
