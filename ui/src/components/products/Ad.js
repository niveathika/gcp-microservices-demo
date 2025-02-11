/*
 *  Copyright (c) 2022, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
 *
 *  WSO2 Inc. licenses this file to you under the Apache License,
 *  Version 2.0 (the "License"); you may not use this file except
 *  in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing,
 *  software distributed under the License is distributed on an
 *  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 *  KIND, either express or implied.  See the License for the
 *  specific language governing permissions and limitations
 *  under the License.
 */
import PropTypes from 'prop-types';

const Ad = (props) => {
    return (
        <div className="container py-3 px-lg-5 py-lg-5">
            <div role="alert">
                <strong>Ad</strong>
                <a href={props.redirect_url} rel="nofollow" >
                    {props.text}
                </a>
            </div>
        </div>
    );
};

Ad.propTypes = {
    redirect_url: PropTypes.string,
    text: PropTypes.string
};

export default Ad;
