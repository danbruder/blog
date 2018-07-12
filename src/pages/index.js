import React from 'react'

import Layout from '../components/layout'

const IndexPage = () => (
  <Layout>
    <div className="w-100 pa3 ph5-ns bg-light-gray flex-ns">
      <div className="w-50-ns w-100">
        <h1 className="f-subheadline-ns lh-solid">
          We <br />Design <br />Custom <br /> Electronics
        </h1>
        <h3 class="f3 fw4 gray">We deliver or you don't pay.</h3>
      </div>
      <div className="relative h4">
        <div
          className="w4 h4 br3 shadow-5"
          style={{
            backgroundSize: 'cover',
            backgroundImage:
              'url(http://www.yuppee.com/wp-content/uploads/2016/04/circuit.jpg)',
          }}
        />
        <div className="mw6 h4 bg-white absolute t-0">
          <label>hey</label>
        </div>
      </div>
    </div>
  </Layout>
)

export default IndexPage
