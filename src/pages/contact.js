import React from 'react'

import Layout from '../components/layout'

const ContactPage = ({ data }) => (
  <Layout>
    <div className="bg-gray-light  ">
      <div className="mw7 pa3 pa5-l center pv3 pv4-l ">
        <div className="mb5">
          <h1>Contact Me</h1>
          <p className="lh-copy">
            I am available for consulting engagements. You can chat with me by
            clicking the chat bubble in the lower right corner.
          </p>
        </div>
      </div>
    </div>
  </Layout>
)

export default ContactPage
