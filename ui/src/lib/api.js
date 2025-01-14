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

const FRONTEND_SVC_URL = 'http://localhost:9098';

export async function getAllQuotes() {
    const response = await fetch(`${FRONTEND_SVC_URL}/quotes.json`);
    const data = await response.json();

    if (!response.ok) {
        throw new Error(data.message || 'Could not fetch quotes.');
    }

    const transformedQuotes = [];

    for (const key in data) {
        const quoteObj = {
            id: key,
            ...data[key]
        };

        transformedQuotes.push(quoteObj);
    }

    return transformedQuotes;
}

export async function getHomePage() {
    const response = await fetch(`${FRONTEND_SVC_URL}`, { credentials: 'include' });
    const data = await response.json();

    if (!response.ok) {
        throw new Error(data.message || 'Could not fetch quotes.');
    }

    return data;
}

export async function getSingleProduct(productId) {
    const response = await fetch(`${FRONTEND_SVC_URL}/product/${productId}`, { credentials: 'include' });
    const data = await response.json();

    if (!response.ok) {
        throw new Error(data.message || 'Could not fetch quote.');
    }

    return data;
}

export async function addProductToCart(requestData) {
    const response = await fetch(`${FRONTEND_SVC_URL}/cart/`, {
        method: 'POST',
        body: JSON.stringify(requestData),
        headers: {
            'Content-Type': 'application/json'
        },
        credentials: 'include'
    });
    const data = await response.json();

    if (!response.ok) {
        throw new Error(data.message || 'Could not add comment.');
    }

    return { };
}

export async function getCartPage() {
    const response = await fetch(`${FRONTEND_SVC_URL}/cart`, { credentials: 'include' });
    const data = await response.json();

    if (!response.ok) {
        throw new Error(data.message || 'Could not fetch quotes.');
    }

    return data;
}

export async function checkout(requestData) {
    const response = await fetch(`${FRONTEND_SVC_URL}/cart/checkout`, {
        method: 'POST',
        body: JSON.stringify(requestData),
        headers: {
            'Content-Type': 'application/json'
        },
        credentials: 'include'
    });
    const data = await response.json();

    if (!response.ok) {
        throw new Error(data.message || 'Could not add comment.');
    }

    return data;
}

export async function getMetadata() {
    const response = await fetch(`${FRONTEND_SVC_URL}/metadata`, { credentials: 'include' });
    const data = await response.json();

    if (!response.ok) {
        throw new Error(data.message || 'Could not fetch quotes.');
    }

    return data;
}

export async function emptyCart() {
    const response = await fetch(`${FRONTEND_SVC_URL}/cart/empty`, { credentials: 'include', method: 'POST' });
    const data = await response.json();

    if (!response.ok) {
        throw new Error(data.message || 'Could not fetch quotes.');
    }

    return data;
}
