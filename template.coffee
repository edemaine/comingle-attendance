## Comingle server URL (the part before /m/ in the meeting URL)
server: 'https://comingle.your.domain'

## Meeting ID (the part after /m/ in the meeting URL)
meeting: 'gLoBaLlYuNiQuEiD7'

## Meeting secret that grants admin access (available under Settings)
secret: 'sPeCiAlSeCrEtCoDe'

## Output a TSV spreadsheet for each specification in this array.
## Each spreadsheet has a row for each user name and a column for each event.
## Each cell gives a number of minutes, either:
##   * 'inMeeting': In the meeting in any form (not necessarily in a room)
##   * 'inRoom': In the meeting and in some room
##   * 'inCompany': In the meeting and in some room with another user
output: [
#  tsv: 'attendance-inMeeting.tsv'
#  user: 'inMeeting'
#,
#  tsv: 'attendance-inRoom.tsv'
#  user: 'inRoom'
#,
#  tsv: 'attendance-inCompany.tsv'
#  user: 'inCompany'
]

## Include/exclude pattern for rooms to count as users being "in a room".
## Use this in particular to ignore uninteresting rooms.
#inRoom:
#  exclude: /bad title pattern/
#  include: [
#    /title pattern/
#    'Room Title'
#    (room) -> room._id.endsWith 'abc'
#  ]

## Number of digits of precision after the decimal point, for the number of
## minutes in each cell of the spreadsheet.  The default, 0, means round to
## the nearest integer.
#precision: 0

## The default sort order ('name') is case-insensitive sorting of the entire
## user name, which usually starts with the first name.  An alternative is to
## sort by 'lastname' (the last word of the name), which can work well if
## everyone provides a first and last name, but in practice we often see
## people forgetting their last name sometimes.
#sort: 'name'

## Default timezone to interpret start/end times, as IANA tz database key.
## See https://en.wikipedia.org/wiki/List_of_tz_database_time_zones for a list.
## If you don't specify a timezone, your computer's timezone will be used.
## (On most operating systems, the timezone is determined by the TZ
## environment variable.  On Windows, this doesn't work, so be sure that the
## TZ environment variable isn't set.)
#timezone: 'US/Eastern'

## Adjust every event start or end time by the specified deltas.
## For example, MIT classes start 5 minutes after the usually specified time.
## Or you might want to count people who stay extra time beyond the advertized
## timeslot, in which case you can add a large amount to the end time.
## Deltas can specify days, hours, minutes, and/or seconds, e.g. +1h -5min
#adjust:
#  start: '+5m'
#  end: '+60m'

## Maximum amount of time that a user might show up "early" to a meeting
## without generating a "pulse" event.  This should be set to slightly larger
## than the Comingle server's pulseFrequency (set in server/log.coffee)
## which defaults to 4 hours, so the default is 4 hours 5 minutes.
#early: '4h5m'

## List of events, each with a start time, an end time, and an optional title.
## Times are specified in ISO 8601 format: yyyy-mm-ddThh:mm:ss
## If a time ends with Z, it will be interpreted in UTC timezone.
## If a time ends with +hh or -hh, it will be ahead or behind UTC timezone.
## Otherwise, they are interpreted in the default timezone specified above.
events: [
  title: 'C01'
  start: '2021-02-18T19:00'
  end: '2021-02-18T20:30'
,
  title: 'C02'
  start: '2021-02-25T19:00'
  end: '2021-02-25T20:30'
]
