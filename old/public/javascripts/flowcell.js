jQuery(document).ready(function($) {

  function minutesBetween(start, end) {
    start_date = new Date(start);
    end_date = new Date(end);
    return (end_date - start_date) / 60000;
  }

  function totalMinutes(datum) {
    return minutesBetween(datum.events[0].time, datum.events[datum.events.length - 1].time);
  }

  var barHeight = 40;
  var height = (barHeight + 10) * flowcell_data.length; 
  var width = 800;
  var padding = 90;
  var x = d3.scale.linear()
    .domain([0, d3.max(flowcell_data, function(datum) { return totalMinutes(datum) })])
    .range([0,width]);
  var y = d3.scale.linear().domain([0, flowcell_data.length]).range([0, height]);

  var flowcells = d3.select("#flowcells").
    append("svg:svg").
    attr("width", width + padding * 2).
    attr("height", height + padding * 2);

  var barGroup = flowcells.append("svg:g").
    attr("transform", "translate("+padding+","+padding+")");

  rects = barGroup.selectAll("rect")
    .data(flowcell_data)
    .enter()
    .append("svg:rect")
    .classed("flowcell-bar", true)
    .attr("x", 0) 
    .attr("y", function(datum, index) { return y(index); })
    .attr("height", barHeight)
    .attr("width", function(datum, index) {return x(totalMinutes(datum));});

  barGroup.selectAll("text")
    .data(flowcell_data)
    .enter()
    .append("svg:text")
    .classed("flowcell-time", true)
    .attr("x", 0)
    .attr("y", function(datum, index) { return y(index); })
    .attr("dx", function(datum, index) {return x(totalMinutes(datum) / 2);})
    .attr("dy", "1.2em")
    .attr("text-anchor", "middle")
    .text(function(datum) { return Math.round(totalMinutes(datum) / 60) + " hours"; });

  barGroup.selectAll("title")
    .data(flowcell_data)
    .enter()
    .append("svg:text")
    .classed("flowcell-title", true)
    .attr("x", 0)
    .attr("y", function(datum, index) { return y(index); })
    .attr("dx", -90)
    .attr("dy", barHeight / 2 + 5)
    .text(function(datum) {return datum["id"];});

  barGroup.selectAll("rect")
    .on("mouseover", function(datum, index) {
      d3.select(this).classed("active", true);
      flowcells.append("svg:rect")
      .classed("flowcell-bubble", true)
      .attr("x", 0)
      .attr("y", function() { return y(index); })
      .attr("width", 100)
      .attr("height", 100)
      .attr("rx", 20)
      .attr("ry", 20)
    })
    .on("mouseout", function(datum, index) {
      d3.select(this).classed("active", false);
      d3.select(".flowcell-bubble").remove();
    });

});
