## Comingle server URL (the part before /m/ in the meeting URL)
server: 'https://comingle.your.domain'

## Meeting ID (the part after /m/ in the meeting URL)
meeting: 'gLoBaLlYuNiQuEiD7'

## Meeting secret that grants admin access (available under Settings)
secret: 'sPeCiAlSeCrEtCoDe'

## If specified, output a TSV spreadsheet with a row for each user name
## and a column for each event.
#tsv: 'attendance.tsv'

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

## Maximum amount of time that a user might show up early to a meeting.
## For efficiency, we only gather Comingle logs around each event window,
## but this might mean we miss someone who shows up early (until they change
## something like switch or star rooms).  By default, we start looking at logs
## an hour before the start time to detect anyone joining the meeting (but
## these minutes don't count for attendance).  Adjust as desired.
#early: '60m'

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
