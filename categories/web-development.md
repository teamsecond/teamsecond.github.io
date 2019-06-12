---
layout: page
permalink: /categories/web-development
---
 
<h3> Posts by Category : {{ page.title }} </h3>

<div class="card">
{% for post in site.categories.web-development %}
 <li class="category-posts"><span>{{ post.date | date_to_string }}</span> &nbsp; <a href="{{ site.baseurl }}{{ post.url }}">{{ post.title }}</a></li>
{% endfor %}
</div>