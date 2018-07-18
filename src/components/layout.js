import React from 'react'
import PropTypes from 'prop-types'
import { StaticQuery, graphql } from 'gatsby'
import Helmet from 'react-helmet'

import Header from './header'
import Footer from './footer'
import favicon from './favicon.ico'
import 'normalize.css/normalize.css'
import 'tachyons/css/tachyons.css'
// layouts/index.js
import 'prismjs/themes/prism.css'
import './layout.css'

const Layout = ({ children, data }) => (
  <StaticQuery
    query={graphql`
      query SiteTitleQuery {
        site {
          siteMetadata {
            title
          }
        }
      }
    `}
    render={data => (
      <>
        <Helmet
          title="Dan Bruder | Elixir Developer"
          link={[{ rel: 'shortcut icon', href: `${favicon}` }]}
        />
        <Header siteTitle={data.site.siteMetadata.title} />
        <div className="">{children}</div>
        <Footer />
        <script
          type="text/javascript"
          dangerouslySetInnerHTML={{
            __html: `window.$crisp=[];window.CRISP_WEBSITE_ID="35215621-0493-4b5e-8e57-f06798774837";(function(){d=document;s=d.createElement("script");s.src="https://client.crisp.chat/l.js";s.async=1;d.getElementsByTagName("head")[0].appendChild(s);})();`,
          }}
        />
      </>
    )}
  />
)

Layout.propTypes = {
  children: PropTypes.node.isRequired,
}

export default Layout
