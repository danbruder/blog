import React from 'react'
import moment from 'moment'

const Footer = () => (
  <div className=" bg--black-10 ">
    <div className="mw9 center f6 w-100 pa3 pa5-ns ">
      <small>{moment().format('YYYY')} danbruder.com</small>
      </div>
  </div>
)

export default Footer
