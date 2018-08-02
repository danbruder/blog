import React from 'react'
import { Link } from 'gatsby'
import { Github, Twitter, Linkedin } from 'react-feather'
import moment from 'moment'

const Footer = () => (
  <div className=" bg--black-10 ">
    <div className="mw7 center tc f6 w-100 pv4 pa3 ph5-l ">
      <div className=" pb1 flex justify-center items-center">
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
      <small className="gray">© {moment().format('YYYY')} Dan Bruder</small>
      <small className="gray"> - </small>
      <small className="gray pt2">
        <Link className="link" to="/resume">
          Resume
        </Link>
      </small>
    </div>
  </div>
)

export default Footer
