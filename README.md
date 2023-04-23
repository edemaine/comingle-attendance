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

## Configuration

To use this tool, you need to create your own **configuration file**,
say `config.coffee` (or name it to match your meeting or class).
Start from a copy of
[`template.coffee`](https://github.com/edemaine/comingle-attendance/blob/main/template.coffee),
which describes the various options you can set.

In particular, you should set the `server` URL, the `meeting` ID,
the meeting `secret`, and list `events` that you want to track.

Alternatively, you can use a `.js` configuration file.
In either case, the last expression in this file should evaluate to an object
with configuration options.

**Do not commit** your config file into Git (or change `template.coffee`),
or risk your meeting and its secret leaking to the world.

## Running the Script

To run this tool on any machine with [NodeJS](https://nodejs.org/) installed,
do one of the following from the command line:

1. Via `npx`:
   ```sh
   npx comingle-attendance config.coffee
   ```
2. Install globally once:
   ```sh
   npm install -g comingle-attendance
   ```
   Thereafter use:
   ```sh
   comingle-attendance config.coffee
   ```
3. Run from a Git clone:
   ```sh
   git clone https://github.com/edemaine/comingle-attendance.git
   cd comingle-attendance
   npm install
   npm run attendance config.coffee
   ```

## Tips

If you want to get a list of all of meetings on your Comingle server,
so you know where to measure attendance/usage (for overall statistics),
run the following command in your Comingle MongoDB shell:

```js
db.log.aggregate([
  {$match: {updated: {$gt: ISODate("2023-01-01")}}}, // recently used meetings
  {$group: {_id: "$meeting"}}, // get set of unique meeting ids
]).map(({_id}) => db.meetings.findOne({_id})) // look up meeting data
```
