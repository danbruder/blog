import React from 'react'
import { Link } from 'gatsby'
import { Github, Twitter, Linkedin } from 'react-feather'
import moment from 'moment'

const Footer = () => (
  <div className=" bg--black-10 ">
    <div className="mw7 center f6 w-100 pa3 ph5-l flex justify-between items-center">
      <small>© {moment().format('YYYY')} Dan Bruder</small>
      <div className="flex items-center">
        <a
          className="hover-green pr3 link gray"
          href="https://github.com/danbruder"
        >
          <Github className="h1 w1" />
        </a>
        <a
          className="hover-green pr3 link gray"
          href="https://twitter.com/danbruder"
        >
          <Twitter className="h1 w1" />
        </a>
        <a
          className="hover-green link gray"
          href="https://linkedin.com/in/thedanbruder"
        >
          <Linkedin className="h1 w1" />
        </a>
      </div>
    </div>
  </div>
)

export default Footer
