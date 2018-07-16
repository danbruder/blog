import React from 'react'
import { Link } from 'gatsby'
import Layout from '../components/layout'
import Meta from '../components/meta'

class Contact extends React.Component {
  render() {
    return (
      <Layout>
        <Meta title="Contact" url="contact" />
        <div className="bg-light-gray">
          <div className="mw9 center w-100 pa3 cf pa5-ns bg-light-gray">
            <h1>Contact Us</h1>
            <div className="cf bt b--black-90 pv3">
              <div className="fl-ns fn w-50-ns w-100 ">
                <h1 className="tl f1 tr-ns pr5 mt3">A. </h1>
              </div>
              <div className="fl-ns fn w-50-ns w-100 ">
                <h2 className="mb0">Chat with us </h2>
                <p className="lh-copy mt0 measure">
                  Theres a little chat bubble in the lower corner of the page.
                  If we're not here, leave an email address and we'll respond.
                </p>
              </div>
            </div>

            <div className="cf bt b--black-90 pv3">
              <div className="fl-ns fn w-50-ns w-100 ">
                <h1 className="tl f1 tr-ns pr5 mt3">B. </h1>
              </div>
              <div className="fl-ns fn w-50-ns w-100 ">
                <h2 className="mb0">Visit us</h2>
                <p className="lh-copy mt0 measure">
                  We're headquartered in the suburbs of Grand Rapids, MI. Come
                  by and we'll take you out to lunch.
                </p>
              </div>
            </div>

            <div className="cf bt b--black-90 pv3">
              <div className="fl-ns fn w-50-ns w-100 ">
                <h1 className="tl f1 tr-ns pr5 mt3">C. </h1>
              </div>
              <div className="fl-ns fn w-50-ns w-100 ">
                <h2 className="mb0">Email us.</h2>
                <p className="lh-copy mt0 measure">
                  Send us an email at info@debassociates.com We're nice people.
                  We care about what we do and about our clients' success. If
                  nothing else, just leave us a wave. 👋
                </p>
              </div>
            </div>
          </div>
        </div>
      </Layout>
    )
  }
}

export default Contact
