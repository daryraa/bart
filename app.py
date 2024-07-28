from transformers import pipeline
from fastapi import FastAPI, Body, HTTPException, Query
from pydantic import BaseModel
import os
import logging
from fastapi.middleware.cors import CORSMiddleware
import requests
from bs4 import BeautifulSoup
from datetime import datetime
from typing import List

os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'

# Konfigurasi logging
logging.basicConfig(level=logging.INFO)

# Token tidak diperlukan jika menggunakan model lokal
model_path = "salamodel/TA-bartindo"
nlp = pipeline("text2text-generation", model=model_path, tokenizer=model_path)

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class TextData(BaseModel):
    text: str

class SummarizationParams(BaseModel):
    max_length: int = 150
    min_length: int = 50

@app.post("/test")
def summarize_text(text_data: TextData = Body(...), params: SummarizationParams = Body(...)):
    logging.info(f"Received text: {text_data.text}")
    logging.info(f"Received params: {params}")

    # Potong teks jika melebihi 1024 karakter
    if len(text_data.text) > 1024:
        text_data.text = text_data.text[:1024]

    # Menghasilkan ringkasan
    result = nlp(text_data.text, max_length=params.max_length, min_length=params.min_length, do_sample=True)
    summary = result[0]['generated_text']
    logging.info(f"Initial Summary result: {summary}")

    # Memastikan ringkasan terdiri dari 3-4 kalimat
    sentences = summary.split('. ')
    if len(sentences) > 4:
        if len(sentences[3].split('.')) > 1:
            summary = '. '.join(sentences[:3]) + '.'
        else:
            summary = '. '.join(sentences[:4]) + '.'
    elif len(sentences) == 4 and sentences[3][-1] != '.':
        summary = '. '.join(sentences[:3]) + '.'

    # Pastikan kalimat terakhir diakhiri dengan titik
    if not summary.endswith('.'):
        summary += '.'
    
    logging.info(f"Final Summary result: {summary}")
    return {"summary_text": summary}

@app.get("/")
def read_root():
    return {"message": "FastAPI is running"}

class Article(BaseModel):
    title: str
    published_time: str
    href: str
    text: str

class ScraperRequest(BaseModel):
    keywords: str
    pages: int

class DETIKScraper:
    def __init__(self, keywords, pages):
        self.keywords = keywords
        self.pages = pages

    def fetch(self, base_url):
        self.base_url = base_url
        self.params = {
            'query': self.keywords,
            'sortby': 'time',
            'page': 2
        }
        self.headers = {
            'sec-ch-ua': '"(Not(A:Brand";v="8", "Chromium";v="99", "Google Chrome";v="99"',
            'sec-ch-ua-platform': "Linux",
            'sec-fetch-site': 'same-origin',
            'user-agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.35 Safari/537.36'
        }
        self.response = requests.get(self.base_url, params=self.params, headers=self.headers)
        return self.response

    def get_articles(self):
        article_lists = []
        for page in range(1, int(self.pages) + 1):
            url = f"{self.base_url}?query={self.keywords}&sortby=time&page={page}"
            page_response = requests.get(url)
            soup = BeautifulSoup(page_response.text, "html.parser")
            articles = soup.find_all("article")
            for article in articles:
                href_tag = article.find("a")
                if href_tag:
                    href = href_tag["href"]
                    title, published_time = self.get_article_details(href)
                    text = self.get_article_text(href)
                else:
                    href = "No Link"
                    title = "No Title"
                    published_time = "No Date"
                    text = "No Content"
                article_lists.append({
                    "title": title,
                    "published_time": published_time,
                    "href": href,
                    "text": text
                })
        self.articles = article_lists
        return self.articles

    def get_article_details(self, href):
        page = requests.get(href)
        soup = BeautifulSoup(page.text, "html.parser")
        title_tag = soup.find("h1", {"class": "detail__title"})
        date_tag = soup.find("div", {"class": "detail__date"})
        title = title_tag.get_text().strip() if title_tag else "No Title"
        published_time = date_tag.get_text().strip() if date_tag else "No Date"
        published_time = published_time.split("|")[0].strip()
        title = title.replace("\r", "").replace("\n", "")
        published_time = published_time.replace("\r", "").replace("\n", "")
        return title, published_time

    @staticmethod
    def get_article_text(href):
        page = requests.get(href)
        soup = BeautifulSoup(page.text, "html.parser")
        body_text = soup.find("div", {"class": "detail__body-text"})
        if body_text:
            paragraphs = body_text.find_all("p")
            article_text = '\n'.join([p.get_text().replace('ADVERTISEMENT', '').replace('SCROLL TO CONTINUE WITH CONTENT', '') for p in paragraphs])
            return article_text.strip()
        else:
            return "No Article Text Found"

@app.get("/articles", response_model=List[Article])
def get_articles(keywords: str = Query(...), pages: int = Query(...)):
    base_url = "https://www.detik.com/search/searchall"
    scraper = DETIKScraper(keywords, pages)
    response = scraper.fetch(base_url)
    articles = scraper.get_articles()
    return articles
