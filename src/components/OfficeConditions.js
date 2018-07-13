import React from 'react'
import moment from 'moment'

import {
  ResponsiveContainer,
  Area,
  AreaChart,
  XAxis,
  YAxis,
  CartesianGrid,
} from 'recharts'

function to_f(c) {
  return (c * 9) / 5 + 32
}

class OfficeConditions extends React.Component {
  state = {
    loading: true,
    error: false,
    data: [],
  }

  componentDidMount() {
    this.fetchData()
  }

  fetchData = () => {
    fetch('https://y0idnoolm1.execute-api.us-east-1.amazonaws.com/production')
      .then(r => r.json())
      .then(r => {
        this.setState({
          loading: false,
          error: false,
          errorMessage: '',
          data: r,
        })
        setTimeout(this.fetchData, 60000)
      })
      .catch(e =>
        this.setState({
          loading: false,
          error: true,
          errorMessage: e,
        })
      )
  }

  render() {
    const { loading, error, data, errorMessage } = this.state
    if (loading) return <div>loading</div>
    if (error) return <div>Something went wrong... check back later.</div>

    return <div className="chart-wrapper">{this.getCharts(data)}</div>
  }

  getCharts = d => {
    let data = d
      .concat([])
      .reverse()
      .map(i => ({
        timestamp: moment(i.timestamp, 'unix').format('h:mm A'),
        hum: parseFloat(i.payload.hum).toFixed(2),
        pres: parseFloat(i.payload.pres).toFixed(2),
        temp: to_f(parseFloat(i.payload.temp)).toFixed(2),
      }))
    return (
      <div className="">
        {this.getChart(data, 'Temperature (°F)', 'temp', [65, 85])}
        {this.getChart(data, 'Pressure (mbar)', 'pres', [980, 1020])}
        {this.getChart(data, 'Humidity (%)', 'hum', [30, 60])}
      </div>
    )
  }

  getChart = (data, label, key, range) => {
    return (
      <ResponsiveContainer width="100%" height={250}>
        <AreaChart
          data={data}
          margin={{ top: 40, right: 10, left: 30, bottom: 0 }}
        >
          <defs>
            <linearGradient id="colorUv" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#82ca9d" stopOpacity={0.7} />
              <stop offset="95%" stopColor="#82ca9d" stopOpacity={0} />
            </linearGradient>
          </defs>
          <XAxis dataKey="timestamp" type="category" />
          <YAxis
            type="number"
            label={{ value: label, angle: -90, position: 'left' }}
            domain={range}
          />
          <CartesianGrid strokeDasharray="3 3" />
          <Area
            type="monotone"
            dataKey={key}
            fill="#01a982"
            stroke="#01a982"
            fillOpacity={0.6}
          />
        </AreaChart>
      </ResponsiveContainer>
    )
  }
}

export default OfficeConditions
