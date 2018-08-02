import React from 'react'
import { graphql, Link } from 'gatsby'
import Img from 'gatsby-image'
import { get } from 'lodash'
import { CheckCircle, Minus, Calendar, MapPin, Activity } from 'react-feather'
import _ from 'lodash'

const ResumePage = ({ data }) => (
  <div className="bg-gray-light  ">
    <div className="mw8 pa3 pa5-l center pv3 pv4-l ">
      <div className="mb5">
        <h1 className="mb0 f1">Dan Bruder</h1>
        <h2 className="mt1 green tracked ttu f4 fw4">Software Developer</h2>
        <h2 className=" fw3 lh-copy">
          I am a software developer focused on client results.{' '}
        </h2>
        <p className="lh-copy">
          I care about everything that brings those results: product
          roadmapping, user experience, performance, quality code, test
          coverage, reliable deployment, uptime, pragmatism and gumption.
        </p>
        <p className="lh-copy">
          I prefer demos over presentations, I like shipping MVPs quickly, and I
          like to celebrate clients' success together.
        </p>
        <p className="lh-copy i ">
          I'm available for contracts for web application development. I prefer
          Elixir/Phoenix and ReactJS, but am comfortable in a number of
          technologies. Email me here:{' '}
          <a href="mailto:dan@debassociates.com">dan@debassociates.com</a>.
        </p>
        <div className="flex-ns bt bw1 pv1 mt4 b--black">
          <div className="mt3 pr3 mw5 w-100">
            <label className="fw7">What I bring to the table</label>
          </div>
          <div className="pr3 pb3 pt0">
            <p className="lh-copy">
              I have 7 years professional software development experience - 5 of
              which have been client facing as an application consultant.
            </p>
            <p className="lh-copy mb0">My work includes:</p>
            <ul className="list ml0 pl3 pt0 mt0">
              {[
                'websites with 10k+ monthly visitors',
                'content managed application with 30k+ entities',
                'multi-million dollar custom e-commerce application',
                'an influence growth platform',
                'landlord management application',
                'non-profit annual report SPA',
                'a touch screen kiosk',
              ].map((i, k) => (
                <li key={k} className="flex items-center pt2">
                  <CheckCircle
                    style={{ marginRight: 8, width: 16, height: 16 }}
                  />
                  <span>{i}</span>
                </li>
              ))}
            </ul>
            <p className="lh-copy mb0">
              I have also shipped multiple embedded firmware projects:
            </p>
            <ul className="list ml0 pl3 pt0 mt0">
              {[
                'a fuel pump motor driver that cut production cost with higher efficiency',
                'USB-C power delivery compliant charger for automotive and furniture industries',
                'cloud enabled environmental sensor',
              ].map((i, k) => (
                <li key={k} className="flex items-center pt2">
                  <CheckCircle
                    style={{ marginRight: 8, width: 16, height: 16 }}
                  />
                  <span>{i}</span>
                </li>
              ))}
            </ul>
            <p className="lh-copy">
              I care <strong>deeply</strong> about my clients' success. Together
              we take steps to make sure we are building the <i>right</i>{' '}
              product - one that solves real world problems effectively.
            </p>
            <p className="lh-copy">
              Once we are working together, I communicate frequently and
              clearly, demoing progress along the way.
            </p>
          </div>
        </div>
        <div className="flex-ns bt bw1 pv1 mt1 b--black">
          <div className="mt3 pr3 mw5 w-100">
            <label className="fw7">Experience</label>
          </div>
          <div className="pr3 pb3 pt0 mt3">
            <div className="pb3">
              <strong>DEB Associates</strong>
              <span className="mono i"> Software Consultant</span>
              <label className="ttu gray f6 db pt1 flex items-center">
                <Calendar style={{ width: 14, height: 14, paddingRight: 4 }} />{' '}
                2017 - present
                <MapPin
                  style={{
                    paddingLeft: 10,
                    width: 14,
                    height: 14,
                    paddingRight: 4,
                  }}
                />
                Grand Rapids, MI
              </label>
              <p className="lh-copy">
                Web applications and embedded software consulting. DEB
                Associates focuses on custom circuit design - I support the
                custom designs with custom software.
              </p>
            </div>
            <div className="pb3">
              <strong>Rapid Development Group</strong>
              <span className="mono i"> Software Consultant</span>
              <label className="ttu gray f6 db pt1 flex items-center">
                <Calendar style={{ width: 14, height: 14, paddingRight: 4 }} />{' '}
                2013 - 2017
                <MapPin
                  style={{
                    paddingLeft: 10,
                    width: 14,
                    height: 14,
                    paddingRight: 4,
                  }}
                />
                Grand Rapids, MI
              </label>
              <p className="lh-copy">
                Worked with clients on a range of web applications. Promoted to
                senior level part way through my time at RDG. Led a DevOps
                initiative as well as ReactJS adoption.
              </p>
            </div>
            <div className="pb3">
              <strong>Belcan Engineering</strong>
              <span className="mono i"> Electrical Engineer</span>
              <label className="ttu gray f6 db pt1 flex items-center">
                <Calendar style={{ width: 14, height: 14, paddingRight: 4 }} />{' '}
                2011 - 2013
                <MapPin
                  style={{
                    paddingLeft: 10,
                    width: 14,
                    height: 14,
                    paddingRight: 4,
                  }}
                />
                Grand Rapids, MI
              </label>
              <p className="lh-copy pt0">
                Wrote embedded software for a component of a GE wind turbine
                (C), desktop applications that assisted in testing aerospace
                software (C#), and reviewed assembly code for an airline cockpit
                instrument.
              </p>
            </div>
          </div>
        </div>
        <div className="flex-ns bt bw1 pv1 mt1 b--black">
          <div className="mt3 pr3 mw5 w-100">
            <label className="fw7">Education</label>
          </div>
          <div className="pr3 pb3 pt0 mt3">
            <div className="pb3">
              <strong>Grand Valley State University</strong>
              <span className="mono i"> B.S. Electrical Engineering</span>
              <label className="ttu gray f6 db pt1 flex items-center">
                <Calendar style={{ width: 14, height: 14, paddingRight: 4 }} />{' '}
                Graduated 2011
              </label>
              <p className="lh-copy">
                Studied under industry experts in Electro-Mechanical
                Compatibility and Electronic Product Development.{' '}
                <i>
                  Senior Thesis: Data Acquisition for Hospital Equipment
                  Tracking.
                </i>
              </p>
            </div>
          </div>
        </div>
        <div className="flex-ns bt bw1 pv1 mt1 b--black">
          <div className="mt3 pr3 mw5 w-100">
            <label className="fw7">My Comfort Zone</label>
          </div>
          <div>
            <div className="pr3 pb3 pt0 mt3 flex flex-wrap">
              <ListWithTitle
                title="Most Used"
                lists={[
                  [
                    'Elixir + Phoenix',
                    'React/ES6',
                    'Apollo',
                    'GraphQL',
                    'Postgres',
                  ],
                ]}
              />
              <ListWithTitle
                title="For Embedded"
                lists={[['C', 'Unity', 'Microchip', 'Cypress']]}
              />
              <ListWithTitle
                title="For IoT"
                lists={[['C++', 'Mbed', 'AWS IoT']]}
              />
            </div>

            <ListWithTitle
              title="I also have used"
              lists={[
                [
                  'PHP',
                  'Rust',
                  'Elm',
                  'Typescript',
                  'Go',
                  'C++',
                  'Bash',
                  'C#',
                  'Swift',
                ],
                [
                  'Redux',
                  'NodeJS',
                  'Webpack',
                  'ReactNative',
                  'socket.io',
                  'Relay',
                  'Drupal',
                  'GatsbyJS',
                  'AWS AppSync',
                  'jQuery',
                  'Turbolinks',
                ],
                [
                  'MySQL',
                  'SQLite',
                  'ElasticSearch',
                  'MongoDB',
                  'DynamoDB',
                  'FaunaDB',
                  'Redis',
                  'Memcached',
                ],
                [
                  'GraphQL',
                  'JSON',
                  'HTTP',
                  'REST',
                  'Websockets',
                  'SOAP',
                  'MQTT',
                  'Thread',
                  'BLE',
                  'I2C',
                  'CAN',
                ],
                [
                  'Apex/Up',
                  'AWS Lambda',
                  'Nginx',
                  'Apache',
                  'Docker',
                  'Rancher',
                  'Kubernetes',
                  'DroneCI',
                  'CircleCI',
                  'Jenkins',
                  'Ansible',
                  'Chef',
                ],
                [
                  'Jest',
                  'Cypress',
                  'Hound',
                  'ExUnit',
                  'Unity',
                  'Selenium',
                  'Behat',
                ],
                ['AWS', 'DigitalOcean', 'Heroku', 'Dokku'],

                ['Github', 'Bitbucket', 'Vim'],
              ]}
            />
          </div>
        </div>
        <div className="flex-ns bt bw1 pv1 mt1 b--black">
          <div className="mt3 pr3 mw5 w-100">
            <label className="fw7">Made it this far?</label>
          </div>

          <div className="mt3">
            Say hi:{' '}
            <a href="mailto:dan@debassociates.com">dan@debassociates.com</a>
          </div>
        </div>
      </div>
    </div>
  </div>
)

const ListWithTitle = ({ title, lists }) => (
  <div className="pb3">
    <label className="b">{title}</label>
    <div className="flex flex-wrap">
      {lists.map((c, ck) => (
        <ul
          key={ck}
          className="list ml0 pl0 pt0 mt0 pr4"
          style={{ width: 200 }}
        >
          {c.map((i, ik) => (
            <li key={ik} className="flex items-center pt2">
              <CheckCircle style={{ marginRight: 8, width: 16, height: 16 }} />
              <span>{i}</span>
            </li>
          ))}
        </ul>
      ))}
    </div>
  </div>
)
export default ResumePage
