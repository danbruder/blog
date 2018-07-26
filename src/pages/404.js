import React from 'react'
import Layout from '../components/layout'
import { Link } from 'gatsby'

const Embed = ({ id, className }) => (
  <div
    className={className}
    dangerouslySetInnerHTML={{
      __html: `<style>.embed-container { position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; max-width: 100%; } .embed-container iframe, .embed-container object, .embed-container embed { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }</style><div class='embed-container'><iframe src='https://www.youtube.com/embed/${id}' frameborder='0' allowfullscreen></iframe></div>`,
    }}
  />
)

const NotFoundPage = () => (
  <Layout>
    <div className="mw7 center pa3 ph5-ns">
      <h1>That page doesn't exist.</h1>
      <h3>But these do:</h3>
      <ul className="">
        <li>
          <Link to="/blog/reflections-on-the-book-functional-web-development-with-elixir-otp-and-phoenix">
            Reflections on the book Functional Web Development with Elixir, OTP,
            and Phoenix
          </Link>
        </li>
        <li>
          <Link to="/blog/about">About me</Link>
        </li>
        <li>
          <Link to="/blog">Blog posts</Link>
        </li>
      </ul>

      <h3>Still here?</h3>
      <h4>Some of my favorites:</h4>
      <div className="flex flex-wrap justify-center">
        <Embed className="w-100 w-50-ns" id="lDKCSheBc-8" />
        <Embed className="w-100 w-50-ns" id="qHrN5Mf5sgo" />
        <Embed className="w-100 w-50-ns" id="Tng6Fox8EfI" />
        <Embed className="w-100 w-50-ns" id="eisuQefYw_o" />
        <Embed className="w-100 w-50-ns" id="gom6nEvtl3U" />
        <Embed className="w-100 w-50-ns" id="lO1z-7cuRYI" />
      </div>
    </div>
  </Layout>
)

export default NotFoundPage
