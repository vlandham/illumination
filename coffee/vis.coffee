
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

      update_scales()

      svg = d3.select(this).selectAll("svg").data([data])
      update_dimensions()
      gEnter = svg.enter().append("svg").append("g")

      baseG = svg.select("g")
        .attr("transform", "translate(#{margin.left},#{margin.top})")

      bars = baseG.append("g")
        .attr("class","bars")


      chart.update()

  update_scales = () ->

    xMax = d3.max(data, (datum) -> datum.duration )
    xScale.domain([0, xMax]).range([0,width])

  update_dimensions = () ->
    height = (data.length + 1) * (barHeight + barMargin)

    svg.attr("width", width + margin.left + margin.right )

    svg.transition()
      .duration(1000)
      .attr("height", height + margin.top + margin.bottom )

  chart.update = () ->
    update_scales()
    update_dimensions()
    allBars = bars.selectAll(".bar")
      .data(data, (d) -> d.id)

    # remove
    allBars.exit().remove()

    # existing
    t = allBars.transition()
    t.duration(800)
      .attr("transform", (d,i) -> "translate(#{0},#{i * (barHeight + barMargin)})")

    allBars.each (bd) ->
      tcurrentX = 0
      t.selectAll("rect").each (rd) ->
        d3.select(this).transition().duration(500).attr("x", tcurrentX)
        tcurrentX = tcurrentX += xScale(rd.duration)

    t.selectAll("rect").transition()
      .duration(500).delay(500)
      .attr("width", (d) -> xScale(d.duration))

    t.select(".flowcell-time").transition()
      .duration(500)
      .attr("x", (d) -> xScale(d.duration))

    # t.select(".total-duration").transition()
    #   .duration(500)
    #   .attr("width", (d) -> xScale(d.duration))

    # new
    b = allBars.enter().append("g")
      .attr("class", "bar")
    b.transition().duration((d,i) -> 50 * i)
      .attr("transform", (d,i) -> "translate(#{0},#{i * (barHeight + barMargin)})")

    b.append("text")
      .attr("class", "flowcell-id")
      .attr("text-anchor", "end")
      .attr("dx", -5)
      .attr("dy", (barHeight / 2) + 5)
      .text((d) -> d.id)
      .on("click", (d) -> root.showFlowcell(d))
      .attr("cursor", "pointer")

    now = moment()
    b.append("text")
      .attr("class", "flowcell-date")
      .attr("text-anchor", "end")
      .attr("dx", -5)
      .attr("dy", (barHeight) - 3)
      .text((d) -> d.start_moment.from(now))

    # b.append("rect")
    #   .attr("class", "total-duration")
    #   .attr("x",0)
    #   .attr("height", barHeight)
    #   .attr("width", (d) -> xScale(d.duration))

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
      .on("click", (d) -> console.log(d.message))


    # hack to make them stack
    # until i think of a better way
    b.each (bd) ->
      currentX = 0
      d3.select(this).selectAll("rect").each (rd) ->
        d3.select(this).attr("x", currentX)
        currentX = currentX += xScale(rd.duration)

    # key = svg.append("g").id("vis-key")
    
  chart.data = (_) ->
    if !arguments.length
      return data
    data = _
    chart

  chart.replace = (new_data) ->
    chart.data(new_data).update()

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
  

    allBars = histogramG.selectAll(".histo")
      .data(histogram)

    allBars.exit().remove()

    hEnter = allBars.enter()
    hEnter.append("rect")
    g = hEnter.append("g")
      .attr("class", "histo-g")
      .attr("transform", (d) -> "translate(#{xScale(d.x)},0)")
      .on("mouseover", (d) -> showDetails(d,this))
      .on("mouseout", (d) -> hideDetails(d,this))
      .on("click", (d) -> root.filterFlowcells(d))

    g.append("rect").attr("class", "histo")
      .attr("y", (d) -> height - yScale(d.y))
      .attr("width", xScale.rangeBand())
      .attr("height", (d) -> yScale(d.y))

    g.append("text")
      .attr("text-anchor", "middle")
      .attr("dx", xScale.rangeBand() / 2)
      .attr("y", height)
      .attr("dy", -5)
      .attr("fill", "white")
      .text((d) -> if d.length then (Math.round((d3.sum(d) / d.length) / 60)) else null)

  showDetails = (d,el) ->
    d3.select(el).append("text")
      .attr("dx", xScale.rangeBand() / 2)
      .attr("text-anchor", "middle")
      .attr("y", (d) -> height - yScale(d.y))
      .attr("dy", (d) -> if d.y < 2 then -5 else 15)
      .attr("fill", (d) -> if d.y < 2 then "black" else "white")
      .text((d) -> d.y)

  hideDetails = (d,el) ->
    dd = d


  return chart

plot  = null
data = []

root.reset = () ->
  console.log('reset')
  plot.replace(data)
  $("#all-link").css("display", "none")

root.showFlowcell = (flowcell_data) ->
  plot.replace([flowcell_data])
  $("#all-link").css("display", "block")
  # d3.select("#all-link").on("click", root.reset())

root.filterFlowcells = (flowcells) ->
  console.log(flowcells)

root.plotData = (selector, data, plot) ->
  d3.select(selector)
    .datum(data)
    .call(plot)

render_vis = (json) ->
  data = parse(json)
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
  d3.select("#all-link").on("click", root.reset)
