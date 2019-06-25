# TEAM SECOND Blog

## 블로그 운영 프로세스

---

![Team second blogging process](./assets/img/github/blog_process.png)

### Three branches 

* **블로그** 저장소의 **마스터(master)** 브랜치:  팀세컨드 블로그의 마스터 브랜치. https://teamsecond.github.io/로 호스팅 되는 브랜치. 공개가능한 내용과 형태의 아티클만 Merge된다.
* **블로그** 저장소의 **소스(source)** 브랜치: 팀세컨드 블로그의 소스 브랜치. 마스터로 Merge되기 전에 raw한 블로그 글들이 리뷰를 거쳐서 Merge된다. 이후에 매니저의 검수를 거쳐서 마스터 브랜치로 Merge된다.
* **로컬** 저장소의 **로컬** 브랜치: 글작성자가 임의로 수정해보고 테스트해볼 수 있는 작성자의 로컬저장소. 블로그 저장소를 fork하여 컨텐츠를 작성한 후, 완성될 경우 블로그의 소스브랜치로 Pull Request를 만들어 리뷰를 받는다.

### Actors

* 블로그 글 작성자 (Writer): 컨텐츠 내용 작성자
* 리뷰어 (Reviewer): 컨텐츠의 내용 검수 및 피드백
* 블로그 관리자 (Manager): 블로그 기능 추가와 디자인 수정 등 전반적인 관리. 새로운 글을 게시 이전에 블로그 검수.

### 블로그 글 작성 및 리뷰 프로세스

#### 블로그 글 작성과 블로그 게시 순서

1. 블로그 저장소의 소스 브랜치를 로컬 저장소로 *fork*
2. Fork한 로컬 저장소에서 컨텐츠 작성
   1. _post에 markdown 글 작성
   2. 필요할 경우 카테고리 생성
3. 블로그 저장소의 소스 브랜치로 Pull Request를 통해 리뷰 요청
   * PR 내용에 리뷰 기간을 명시
   * 블로그 관리자 또는 글 작성자가 리뷰어 할당
   * **리뷰기간동안 fork한 저장소를 별도로 호스팅하여 리뷰어들이 보도록 할 수 있다 (아래의 Deploying the blog publicly 참고)**
4. 리뷰어들이 모두 리뷰를 마치면 소스 브랜치에 작성자가 *merge*
5. 블로그 관리자는 소스 브랜치에 반영된 컨텐츠들을 검수 및 정리하여 블로그 저장소의 마스터 브랜치에 반영하여 웹으로 공개한다.
   * 블로그 글에 대한 내용은 수정하지 않는다.
   * 블로그의 기능을 추가하거나 디자인을 수정할 수 있다.
   * 기능 및 디자인 수정으로 블로그 글에 영향이 있을 경우 글 작성자와 협의한다.

#### 로컬 저장소에서 블로그 저장소의 소스 브랜치로 PR
컨텐츠의 내용을 리뷰하기 위한 단계

#### 블로그 저장소의 소스 브랜치에서 블로그 저장소의 마스터 브랜치로 PR
하나 또는 다수의 리뷰된 컨텐츠를 호스팅된 사이트에 게시하기 위한 단계.
작성된 블로그 글의 내용 뿐만 아니라 기능과 디자인 변경사항까지 포함해서 최종 산출물을 만든다.

## 리뷰를 위해 이 블로그를 테스트하는 방법

---
### Prerequisite

- Install ruby, gem, bundler
- Install Jekyll: https://jekyllrb.com/docs/installation/

### Testing the blog locally
```
bundle install
bundle exec jekyll serve --watch
// http://127.0.0.1:4000
```

### Deploying the blog publicly
```
bundle install
bundle exec jekyll serve --host 0.0.0.0 --port <port> --watch
// http://<your-ip>:<port>
```
