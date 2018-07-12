import React from 'react'
import { Link } from 'gatsby'
import Headroom from 'react-headroom'

const Header = ({ siteTitle }) => (
  <Headroom>
    <div className="w-100 pa3 ph5-ns bg-white">
      <div className="db dt-ns mw9 center w-100">
        <div className="db dtc-ns v-mid tl w-50">
          <Link to="/" className="dib f5 f4-ns fw6 mt0 mb1 link black-70">
            {siteTitle}
          </Link>
        </div>
        <div className="db dtc-ns v-mid w-100 tl tr-ns mt2 mt0-ns">
          <Link
            to="/specialties"
            className="f6 fw6 hover-blue link black-70 mr2 mr3-m mr4-l dib"
          >
            Specialties
          </Link>
        </div>
      </div>
    </div>
  </Headroom>
)

export default Header
