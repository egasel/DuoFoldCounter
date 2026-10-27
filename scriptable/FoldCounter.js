// Fold Counter for iPhone Duo, for the Scriptable app.
//
// Logging: two Shortcuts run this script with the "Run Script" action. The
// "When iPhone is Opened" one passes the parameter `open` and the "When iPhone
// is Closed" one passes `close`.
// Widget: add a Scriptable widget to the Home Screen and pick this script.
// In the app: shows the counts and lets you preview the widget or reset.

const FILE_NAME = "fold-counter.json"

let fm
try {
  fm = FileManager.iCloud()
} catch (e) {
  fm = FileManager.local()
}
const path = fm.joinPath(fm.documentsDirectory(), FILE_NAME)

function dayKey(date) {
  const pad = (n) => String(n).padStart(2, "0")
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

async function load() {
  if (!fm.fileExists(path)) return { days: {}, since: null }
  if (!fm.isFileDownloaded(path)) await fm.downloadFileFromiCloud(path)
  return JSON.parse(fm.readString(path))
}

function save(stats) {
  fm.writeString(path, JSON.stringify(stats))
}

function today(stats) {
  return stats.days[dayKey(new Date())] || { opens: 0, closes: 0 }
}

function total(stats) {
  return Object.values(stats.days).reduce(
    (sum, day) => ({ opens: sum.opens + day.opens, closes: sum.closes + day.closes }),
    { opens: 0, closes: 0 }
  )
}

function record(stats, event) {
  const key = dayKey(new Date())
  const day = stats.days[key] || { opens: 0, closes: 0 }
  if (event === "open") day.opens += 1
  else day.closes += 1
  stats.days[key] = day
  if (!stats.since) stats.since = key
  save(stats)
  return day
}

// Widget

const primary = Color.dynamic(new Color("#1c1c1e"), new Color("#ffffff"))
const secondary = Color.dynamic(new Color("#6c6c70"), new Color("#aeaeb2"))
const fmt = (n) => n.toLocaleString()

function addCount(parent, value, label) {
  const row = parent.addStack()
  row.bottomAlignContent()
  const number = row.addText(fmt(value))
  number.font = Font.boldRoundedSystemFont(30)
  number.textColor = primary
  number.lineLimit = 1
  number.minimumScaleFactor = 0.5
  row.addSpacer(4)
  const caption = row.addText(label)
  caption.font = Font.mediumSystemFont(13)
  caption.textColor = secondary
}

function addColumn(parent, heading, count) {
  const column = parent.addStack()
  column.layoutVertically()
  const title = column.addText(heading.toUpperCase())
  title.font = Font.semiboldSystemFont(11)
  title.textColor = secondary
  column.addSpacer(4)
  addCount(column, count.opens, "opens")
  addCount(column, count.closes, "closes")
}

function buildWidget(stats, family) {
  const todayCount = today(stats)
  const totalCount = total(stats)
  const widget = new ListWidget()
  // iOS decides when widgets actually refresh; this asks for every 5 minutes.
  widget.refreshAfterDate = new Date(Date.now() + 5 * 60 * 1000)

  if (family === "accessoryInline") {
    widget.addText(`${fmt(todayCount.opens)} opens · ${fmt(todayCount.closes)} closes`)
    return widget
  }
  if (family === "accessoryRectangular") {
    const title = widget.addText("Folds today")
    title.font = Font.headline()
    widget.addText(`${fmt(todayCount.opens)} opens · ${fmt(todayCount.closes)} closes`)
    const all = widget.addText(`All time ${fmt(totalCount.opens)} · ${fmt(totalCount.closes)}`)
    all.textOpacity = 0.7
    return widget
  }

  widget.backgroundColor = Color.dynamic(new Color("#ffffff"), new Color("#1c1c1e"))
  if (family === "medium" || family === "large") {
    const row = widget.addStack()
    addColumn(row, "Today", todayCount)
    row.addSpacer()
    addColumn(row, "All time", totalCount)
    row.addSpacer()
    widget.addSpacer()
    if (stats.since) {
      const since = widget.addText(`Counting since ${stats.since}`)
      since.font = Font.systemFont(11)
      since.textColor = secondary
    }
  } else {
    addColumn(widget, "Folds today", todayCount)
    widget.addSpacer()
    const all = widget.addText(`All time ${fmt(totalCount.opens)} · ${fmt(totalCount.closes)}`)
    all.font = Font.systemFont(11)
    all.textColor = secondary
    all.lineLimit = 1
    all.minimumScaleFactor = 0.6
  }
  return widget
}

// In the app

async function showMenu(stats) {
  const t = today(stats)
  const all = total(stats)
  const alert = new Alert()
  alert.title = "Fold Counter"
  alert.message =
    `Today: ${fmt(t.opens)} opens · ${fmt(t.closes)} closes\n` +
    `All time: ${fmt(all.opens)} opens · ${fmt(all.closes)} closes`
  alert.addAction("Preview widget")
  alert.addDestructiveAction("Reset all counts")
  alert.addCancelAction("Done")
  const choice = await alert.presentAlert()

  if (choice === 0) {
    await buildWidget(stats, "medium").presentMedium()
  } else if (choice === 1) {
    const confirm = new Alert()
    confirm.title = "Reset all counts?"
    confirm.message = "This clears today's and all-time counts."
    confirm.addDestructiveAction("Reset")
    confirm.addCancelAction("Cancel")
    if ((await confirm.presentAlert()) === 0) save({ days: {}, since: null })
  }
}

// Main

const stats = await load()
const event = String(args.shortcutParameter || "").trim().toLowerCase()

if (event === "open" || event === "close") {
  const day = record(stats, event)
  Script.setShortcutOutput(`${day.opens} opens · ${day.closes} closes today`)
} else if (config.runsInWidget) {
  Script.setWidget(buildWidget(stats, config.widgetFamily))
} else {
  await showMenu(stats)
}
Script.complete()
