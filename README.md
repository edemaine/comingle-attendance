# Comingle Attendance Tracking

[Comingle](https://github.com/edemaine/comingle/) is an open-source online
meeting tool, which automatically logs users' behavior (joining/leaving the
meeting, joining/leaving rooms, etc.).
This standalone command-line tool uses those logs to determine:

* **Attendance**: How long was each user in the meeting, or at least one room,
  of the specified date/time ranges?
* **Popular topics**:
  Which rooms were the most popular within those same date/time ranges?

One application is **measuring attendance in a class**.  If the class re-uses
the same Comingle meeting for several discrete meeting times (classes/events),
you specify the start/end time for each such event.   This tool measures
participation within each event time block, and can output a spreadsheet with
a row for each name and a column for each event, where the cell indicates the
number of minutes of attendance (currently the number of minutes they are in
at least one room).

## Usage

To run this script from a Git repo clone, do the following:

1. `npm install`
2. Copy `template.coffee` to `config.coffee` (or some other filename, e.g.,
   `my-class.coffee`).
3. Edit `config.coffee` to fill in the specifics for your meeting:
   * In particular, set the `server` URL, the `meeting` ID,
     and the meeting `secret`; and add `events` you want to track.
   * Read [`template.coffee`](https://github.com/edemaine/comingle-attendance/blob/main/template.coffee)
     for descriptions of the various options.
   * **Do not commit** your config file into Git (or change `template.coffee`),
     or risk your meeting and its secret leaking to the world.
4. `npm run attendance config.coffee`
