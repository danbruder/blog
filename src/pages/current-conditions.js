import React from 'react'
import { Link } from 'gatsby'
import Layout from '../components/layout'
import Meta from '../components/meta'

import OfficeConditions from '../components/OfficeConditions'

class CurrentConditionsPage extends React.Component {
  render() {
    let link = (
      <Link to="/blog/iot-demo-indoor-environmental-sensor-pack-with-mbed-and-aws-iot">
        here
      </Link>
    )
    return (
      <Layout>
        <Meta title="Current Office Conditions" url="current-conditions" />
        <div className="bg-light-gray ">
          <div className="mw9 tc-ns center w-100 pa3 pa5-ns bg-light-gray">
            <h1>Current Office Conditions</h1>
            <p className="measure lh-copy center-ns">
              We have an environmental sensor set up in the office to track our
              working conditions. Data is updated every 10 minutes. We wrote
              about it {link}.
            </p>
            <OfficeConditions />
          </div>
        </div>
      </Layout>
    )
  }
}

export default CurrentConditionsPage
