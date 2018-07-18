import React from 'react'
import { Link } from 'gatsby'
import { Github, Twitter, Linkedin } from 'react-feather'
import moment from 'moment'

const Footer = () => (
  <div className=" bg--black-10 ">
    <div className="mw7 center f6 w-100 pa4 ph5-ns flex justify-between items-center">
      <small>© {moment().format('YYYY')} Dan Bruder</small>
      <div className="flex items-center">
        <a
          className="hover-green pr3 link gray"
          href="https://github.com/danbruder"
        >
          <Github />
        </a>
        <a
          className="hover-green pr3 link gray"
          href="https://twitter.com/danbruder"
        >
          <Twitter />
        </a>
        <a
          className="hover-green link gray"
          href="https://linkedin.com/in/thedanbruder"
        >
          <Linkedin />
        </a>
      </div>
    </div>
  </div>
)

export default Footer
