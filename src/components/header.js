import React from 'react'
import { Link } from 'gatsby'
import logo from './logo.svg'
import Headroom from 'react-headroom'

const Header = ({ siteTitle }) => (
  <Headroom>
    <div className="w-100 pa3 ph5-ns bg-white">
      <div className="db dt-ns mw9 center w-100">
        <div className="db dtc-ns v-mid tl w-50">
          <div className="flex items-center">
            <img className="h2 w2" src={logo} />
            <Link to="/" className="dib f5 f4-ns fw7 mt0 mb1 link black-90">
              {siteTitle}
            </Link>
          </div>
        </div>
        <div className="db dtc-ns v-mid w-100 tl tr-ns mt2 mt0-ns">
          <Link
            to="/services"
            className="f6 fw6 hover-green link black-70 mr2 mr3-m mr4-l dib"
          >
            Services
          </Link>
          <Link
            to="/projects"
            className="f6 fw6 hover-green link black-70 mr2 mr3-m mr4-l dib"
          >
            Projects
          </Link>
          <Link
            to="/blog"
            className="f6 fw6 hover-green link black-70 mr2 mr3-m mr4-l dib"
          >
            Blog
          </Link>
          <Link
            to="/contact"
            className="f6 fw6 hover-green link black-70 mr2 mr3-m mr4-l dib"
          >
            Contact
          </Link>
        </div>
      </div>
    </div>
  </Headroom>
)

export default Header
