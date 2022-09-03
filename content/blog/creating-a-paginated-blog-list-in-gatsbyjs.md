---
date: 2018-07-20
title: Creating a paginated blog list in GatsbyJS
slug: creating-a-paginated-blog-list-in-gatsbyjs
taxonomies: 
    category: [Frontend]
    tags:
      - gatsby
      - jam
---

Here's how I added the pagination to the blog listing on this site. 

To create pages in Gatsby, you implement the `createPage` API in `gatsby-node.js`. 

Let's start with the full example and then break it down: 

```js
var path = require('path')
var _ = require('lodash')

const PAGE_SIZE = 10

exports.createPages = ({ graphql, actions }) => {
  const { createPage } = actions
  const blogListTemplate = path.resolve(`src/templates/blogList.js`)
  
  return new Promise((resolve, reject) => {
    resolve(
      graphql(
        `
          query {
            posts: allContentfulPost(sort: { order: DESC, fields: [date] }) {
              edges {
                node {
                  slug
                }
              }
            }
          }
        `
      ).then(result => {
        if (result.errors) {
          reject(result.errors)
        }

        // Break the entries into chunks according to
        let chunks = _.chunk(result.data.posts.edges, PAGE_SIZE)
        
        // For each of the chunks, call createPage()
        chunks.forEach((chunk, index) => {
          createPage({
            path: `blog/page/${index + 1}`,
            component: blogListTemplate,
            context: {
              skip: PAGE_SIZE * index,
              limit: PAGE_SIZE,
              pageNumber: index + 1,
              hasNextPage: index != chunks.length - 1,
              nextPageLink: `/blog/page/${index + 2}`,
            },
          })
        })
      })
    )
  })
}
```

The interesting part is using the `chunk` function from [lodash](https://lodash.com/docs/4.17.10#chunk) to break our array of posts into chunks (in our case pages):

```js,hl_lines=2
// Break the entries into chunks according to
let chunks = _.chunk(result.data.posts.edges, PAGE_SIZE)

// For each of the chunks, call createPage()
chunks.forEach((chunk, index) => {
  createPage({
    path: `blog/page/${index + 1}`,
    component: blogListTemplate,
    context: {
      skip: PAGE_SIZE * index,
      limit: PAGE_SIZE,
      pageNumber: index + 1,
      hasNextPage: index != chunks.length - 1,
      nextPageLink: `/blog/page/${index + 2}`,
    },
  })
})
```

Then for each of those chunks, we call `createPage()`

```js,hl_lines=6-16
// Break the entries into chunks according to
let chunks = _.chunk(result.data.posts.edges, PAGE_SIZE)

// For each of the chunks, call createPage()
chunks.forEach((chunk, index) => {
  createPage({
    path: `blog/page/${index + 1}`,
    component: blogListTemplate,
    context: {
      skip: PAGE_SIZE * index,
      limit: PAGE_SIZE,
      pageNumber: index + 1,
      hasNextPage: index != chunks.length - 1,
      nextPageLink: `/blog/page/${index + 2}`,
    },
  })
})
```

For create page, we pass the path we want the page to be accessible at, the component that will be rendered, and the graphql context that we want available to the rendered component. 

In this case, I have added page metadata to the context so that I can use it in my `blogList` template to determine whether to show the next page or not. 

Here's the `BlogListPage` component:

```js
import React from 'react'
import { graphql, Link } from 'gatsby'
import { get } from 'lodash'

import Layout from '../components/layout'
import BlogTeaser from '../components/BlogTeaser'

const BlogListPage = ({ data, pageContext }) => (
  <Layout>
    <div className="bg-gray-light ">
      <div className="mw7 center w-100 pa3 pv4-ns pa5-l ">
        {get(data, 'posts.edges', []).map((edge, key) => (
          <BlogTeaser data={edge} key={key} />
        ))}
        {pageContext &&
          pageContext.hasNextPage && (
            <Link class="flex items-center" to={pageContext.nextPageLink}>
              <small>Next page</small>
            </Link>
          )}
      </div>
    </div>
  </Layout>
)

export default BlogListPage

export const pageQuery = graphql`
  fragment PostTeaserFragment on ContentfulPost {
    title
    date(formatString: "MMMM D, YYYY")
    slug
    category {
      title
    }
    body {
      childMarkdownRemark {
        timeToRead
      }
    }
  }
  query BlogListPageQuery($skip: Int, $limit: Int) {
    posts: allContentfulPost(
      skip: $skip
      limit: $limit
      sort: { order: DESC, fields: [date] }
    ) {
      edges {
        node {
          ...PostTeaserFragment
        }
      }
    }
  }
`
```

In the `pageQuery`, I use `skip` and `limit` from the `context` we passed to `createPage` in `gatsby-node.js` to get the posts for this page:

```js,hl_lines=15 17 18
export const pageQuery = graphql`
  fragment PostTeaserFragment on ContentfulPost {
    title
    date(formatString: "MMMM D, YYYY")
    slug
    category {
      title
    }
    body {
      childMarkdownRemark {
        timeToRead
      }
    }
  }
  query BlogListPageQuery($skip: Int, $limit: Int) {
    posts: allContentfulPost(
      skip: $skip
      limit: $limit
      sort: { order: DESC, fields: [date] }
    ) {
      edges {
        node {
          ...PostTeaserFragment
        }
      }
    }
  }
`
```

Then I can use that data in my `BlogListPage` component to conditionally render the next page link: 

```js,hl_lines=1 8-13 
const BlogListPage = ({ data, pageContext }) => (
  <Layout>
    <div className="bg-gray-light ">
      <div className="mw7 center w-100 pa3 pv4-ns pa5-l ">
        {get(data, 'posts.edges', []).map((edge, key) => (
          <BlogTeaser data={edge} key={key} />
        ))}
        {pageContext &&
          pageContext.hasNextPage && (
            <Link class="flex items-center" to={pageContext.nextPageLink}>
              <small>Next page</small>
            </Link>
          )}
      </div>
    </div>
  </Layout>
)
```


Check it out here: [https://github.com/danbruder/blog/blob/master/gatsby-node.js](https://github.com/danbruder/blog/blob/master/gatsby-node.js)

And here it is in action: [https://danbruder.com/blog/page/1](https://danbruder.com/blog/page/1).
