
root = exports ? this

minutes_between = (start, end) ->
 (new Date(end) - new Date(start)) / 60000

minutes_total = (flowcell) ->
  minutes_between(flowcell.events[0].time, flowcell.events[flowcell.events.length - 1].time)

event_classifier = (event) ->
  msg = event.message
  if msg.match /^running steps/
    "other"
  else if msg.match /^processing unaligned.*/g
    "unaligned"
  else if msg.match /^distributing/g
    "distributing"
  else if msg.match /.*export.*/g
    "aligned"
  else if msg.match /.*undetermined.*/g
    "undetermined"
  else if msg.match /.*fastqc.*/g
    "fastqc"
  else
    "other"

parse = (rawData) ->
  rawData.forEach (rd) ->
    rd.duration = minutes_total(rd)
    rd.start_moment = moment(new Date(rd.events[0].time))
    rd.events.forEach (ev,i) ->
      duration = 0
      next_event = rd.events[i+1]
      if next_event
        duration = minutes_between(ev.time, next_event.time)
      ev.duration = duration
      ev.type = event_classifier(ev)
  rawData

  rawData.sort (a,b) -> b.start_moment - a.start_moment

BarCharts = () ->
  data = []
  svg = null
  bars = []
  width = 700
  height = 0
  margin = {top: 20, right: 80, bottom: 20, left: 100}
  barHeight = 40
  barMargin = 10

  xScale = d3.scale.linear()
  yScale = d3.scale.linear()
  colorScale = d3.scale.category10()

  chart = (selection) ->
    selection.each (rawData) ->
      data = rawData
      height = data.length * (barHeight + barMargin)

      xMax = d3.max(data, (datum) -> datum.duration )
      xScale.domain([0, xMax]).range([0,width])

      svg = d3.select(this).selectAll("svg").data([data])
      gEnter = svg.enter().append("svg").append("g")
      svg.attr("width", width + margin.left + margin.right )
      svg.attr("height", height + margin.top + margin.bottom )

      baseG = svg.select("g")
        .attr("transform", "translate(#{margin.left},#{margin.top})")

      bars = baseG.append("g")
        .attr("class","bars")


      chart.update()


  chart.update = () ->
    newBars = bars.selectAll(".bar")
      .data(data)

    newBars.exit().remove()

    b = newBars.enter().append("g")
      .attr("class", "bar")
      .attr("transform", (d,i) -> "translate(#{0},#{i * (barHeight + barMargin)})")

    b.append("text")
      .attr("class", "flowcell-id")
      .attr("text-anchor", "end")
      .attr("dx", -5)
      .attr("dy", (barHeight / 2) + 5)
      .text((d) -> d.id)

    now = moment()
    b.append("text")
      .attr("class", "flowcell-date")
      .attr("text-anchor", "end")
      .attr("dx", -5)
      .attr("dy", (barHeight) - 3)
      .text((d) -> d.start_moment.from(now))

    b.append("rect")
      .attr("class", "total-duration")
      .attr("x",0)
      .attr("height", barHeight)
      .attr("width", (d) -> xScale(d.duration))

    b.append("text")
      .attr("class", "flowcell-time")
      .attr("text-anchor", "start")
      .attr("x", (d) -> xScale(d.duration))
      .attr("dx", 5)
      .attr("dy", (barHeight / 2) + 5)
      .text((d) -> "#{Math.round(d.duration / 60)} hours")

    b.selectAll("rect").data((d) -> d.events)
      .enter().append("rect")
      .attr("height", barHeight)
      .attr("width", (d) -> xScale(d.duration))
      .attr("x", 0)
      .attr("fill", (d) -> colorScale(d.type))

    # hack to make them stack
    # until i think of a better way
    b.each (bd) ->
      currentX = 0
      d3.select(this).selectAll("rect").each (rd) ->
        d3.select(this).attr("x", currentX)
        currentX = currentX += xScale(rd.duration)

    # key = svg.append("g").id("vis-key")


  return chart

Histogram = () ->
  data = []
  durations = []
  svg = null
  histogramG = null
  baseG = null
  height = 400
  width = 800
  margin = {top: 20, right: 20, bottom: 60, left: 20}
  barHeight = 40
  histogram = null
  xScale = null
  yScale = null

  pull_out_durations = (data) ->
    durations = data.map (d) -> d.duration
    durations = durations.filter (d) -> d > 240 and d < 10080
    durations

  chart = (selection) ->
    selection.each (rawData) ->
      data = rawData
      durations = pull_out_durations(data)

      svg = d3.select(this).selectAll("svg").data([data])
      gEnter = svg.enter().append("svg").append("g")

      svg.attr("width", width + margin.left + margin.right )
      svg.attr("height", height + margin.top + margin.bottom )

      baseG = svg.select("g")
        .attr("transform", "translate(#{margin.left},#{margin.top})")


      baseG.append("text")
        .attr("x", 0)
        .attr("y", height + margin.bottom / 2)
        .text("Average Time Taken (hours) ->")

      baseG.append("text")
        .attr("x", 0)
        .attr("dy", -(margin.right / 2))
        .attr("transform", "translate(0,#{height/2 + (height/3)})rotate(-90)")
        .text("Flowcell Run Count")

      histogramG = baseG.append("g")
        .attr("class","histogram-bars")

      chart.update()

  chart.update = () ->
    histogram = d3.layout.histogram().bins(25)(durations)

    xScale = d3.scale.ordinal().domain(histogram.map((d) -> (d.x)))
      .rangeRoundBands([0, width])
    yScale = d3.scale.linear().domain([0,d3.max(histogram.map((d) -> d.y))])
      .range([0, height])
  

    newBars = histogramG.selectAll(".histo")
      .data(histogram)

    newBars.exit().remove()

    hEnter = newBars.enter()
    hEnter.append("rect")
      .attr("class", "histo")
      .attr("x", (d) -> xScale(d.x))
      .attr("y", (d) -> height - yScale(d.y))
      .attr("width", xScale.rangeBand())
      .attr("height", (d) -> yScale(d.y))
      .on("mouseover", (d) -> console.log(d.map((e) -> Math.round(e/60))))

    hEnter.append("text")
      .attr("text-anchor", "middle")
      .attr("x", (d) -> xScale(d.x))
      .attr("dx", xScale.rangeBand() / 2)
      .attr("y", height)
      .attr("dy", -5)
      .attr("fill", "white")
      .text((d) -> if d.length then (Math.round((d3.sum(d) / d.length) / 60)) else null)


  return chart

root.plotData = (selector, data, plot) ->
  d3.select(selector)
    .datum(data)
    .call(plot)

render_vis = (json) ->
  data = parse(json)
  console.log(data)
  plot = BarCharts()
  root.plotData("#vis", data, plot)
  histogram = Histogram()
  root.plotData("#times", data, histogram)


  durations = data.map (d) -> d.duration
  durations = durations.filter (d) -> d > 240 and d < 10080
  durations_avg = (Math.round((d3.sum(durations) / durations.length) / 60))
  $("#avg-stat").html("#{durations_avg} hours")
$ ->
  d3.json "flowcells.json", render_vis
