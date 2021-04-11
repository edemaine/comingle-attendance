fs = require 'fs'
vm = require 'vm'
fetch = require 'node-fetch'
{toDate} = require 'date-fns-tz'
CoffeeScript = require 'coffeescript'
EJSON = require 'ejson'

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
