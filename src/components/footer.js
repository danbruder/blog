import React from 'react'
import { Link } from 'gatsby'

const Footer = () => (
  <div className=" mw9 center">
    <div className="f6 justify-start items-start flex flex-wrap bg--black-10 w-100 pa5 ">
      <div className="pa3 mw5">
        <h3>Like what you see?</h3>
        <div className="pt2">
          <Link to="/contact" className="link ba bw1 pa2 ph3">
            Say hi
          </Link>
        </div>
      </div>

      <div className="pa3 mw5">
        <h2 className="f5">Services</h2>
        <div className="pt2">
          <Link to="/services/circuit-design" className="link">
            Circuit Design
          </Link>
        </div>
        <div className="pt2">
          <Link to="/services/design-for-emc" className="link">
            Design for EMC
          </Link>
        </div>
        <div className="pt2">
          <Link to="/services/software-development" className="link">
            Software Development
          </Link>
        </div>
      </div>

      <div className="pa3 mw5">
        <h2 className="f5">Explore</h2>
        <div className="pt2">
          <Link to="/current-conditions" className="link">
            Current Office Conditions
          </Link>
        </div>
      </div>

      <div className="pa3 mw5">
        <h2 className="f5">Connect</h2>
        <div className="pt2">
          <a href="/" className="link">
            Facebook
          </a>
        </div>
        <div className="pt2">
          <a href="/" className="link">
            Instagram
          </a>
        </div>
      </div>

      <div className="measure pa3">
        <h2 className="f5">About Us</h2>
        <p className="lh-copy">
          DEB Associates helps companies through the entire electronics design
          process. Our team is smart, reliable, and deeply knowlegeable about
          the intricicies of circuit design, PCB layout, and EMC.
        </p>
      </div>
    </div>
    <div className="mw9 center w-100 pa5 ">
      <hr />
      <small>DEB Associates</small>
      <small> 2018</small>
    </div>
  </div>
)

export default Footer
//<label className="i lh-copy">
//What's it like working with us?{' '}
//<a className="link primary" href="/">
//Read our playbook.
//</a>
//</label>
