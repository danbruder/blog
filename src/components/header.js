import React from 'react'
import { Link } from 'gatsby'
import Headroom from 'react-headroom'
import myface from './myface.jpeg'

const Header = ({ siteTitle }) => (
  <Headroom>
    <div className="w-100 bg-white">
      <div className="pa3 mw7 ph5-l center ">
        <div className="db dt-l   w-100">
          <div className="db dtc-l v-mid tl w-50">
            <div className="flex items-center">
              <Link
                to="/"
                className="flex items-center dib f5 f4-l fw7 mt0 mb1 link black-90"
              >
                <img className="mr2 br-100 w2 h2" src={myface} />
                {siteTitle}
              </Link>
            </div>
          </div>
          <div className="db dtc-l v-mid w-100 tl tr-l mt2 mt0-l">
            <Link
              to="/projects"
              className="f6 fw6 hover-green link black-70 dib mr2"
            >
              Projects
            </Link>
            <Link
              to="/blog/about"
              className="f6 fw6 hover-green link black-70 dib"
            >
              About Me
            </Link>
          </div>
        </div>
      </div>
    </div>
  </Headroom>
)

export default Header
