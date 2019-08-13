---
title: "[File/Disk Manager] 큐브리드 파일은 어떻게 관리될까?"
layout: post
author: Jaeeun Kim
categories:
  - cubrid-internal
summary: 큐브리드 파일 아키텍쳐 <br/> (CUBRID File Architecture)
---

# **큐브리드 파일은 어떻게 관리될까?**

#### - CUBRID File Architecture -
<br/>
이번 글부터는 파일과 파일매니저에 대하여 알아본다. 파일매니저는 볼륨매니저로부터 섹터를 예약하여 파일을 생성/제거하고, 페이지를 할당하고, 필요할 경우 추가적인 섹터를 요청하는 등 파일의 공간을 관리하는 역할을 한다. 파일 또한 볼륨과 마찬가지로 저장되는 데이터의 목적에 따라 영구파일과 임시파일로 나뉜다. 영구파일과 임시파일은 전체적인 구조는 같으나 파일테이블의 이용방법이나 오퍼레이션들의 동작이 조금씩 다르다.  

이 포스트에서는 다음의 내용을 다룬다.

* File Overview
* 파일 헤더 (File Header)
* 파일 테이블 (File Table, ftab)

<br/>

## File Overview

---

#### 볼륨과 파일

볼륨과 파일 둘다 최소한의 IO단위인 페이지들의 집합이지만 볼륨은 물리적인 묶음(OS 파일)이고 파일은 논리적인 묶음이다. 파일은 볼륨매니저로부터 예약한 섹터들로 이루어져 있으며, 이 섹터들은 연속적이지 않을 수 있고 심지어는 여러 볼륨에 걸쳐있을 수도 있다. 파일은 섹터단위로 페이지들을 확보하고 필요한 만큼 할당하여 사용하고 예약해둔 섹터를 모두사용하면 추가적인 섹터를 예약한다. 파일은 특정 목적을 위한 섹터들의 묶음으로 큐브리드에서 데이터를 관리하는 핵심적인 단위이다. 앞서 살펴보았던 볼륨매니저도 결국 이 파일들의 공간할당 요청을 처리하기 위해 섹터들을 관리하고 OS로부터 추가적인 공간을 요청하기도 하는 것이다. 

#### 파일테이블 페이지와 유저 페이지

볼륨매니저가 OS로부터 공간을 할당받고 할당받은 공간을 섹터단위로 나누어 섹터의 예약요청을 처리한 것과 같이, 파일매니저는 볼륨으로부터 공간(섹터)을 할당 받고 할당받은 섹터를 페이지단위로 나누어 파일내에서 페이지의 할당을 처리한다. 이를 위해 볼륨매니저는 섹터관리를 위한 시스템페이지와 일반 페이지로 페이지들을 구분하였고, 시스템페이지는 볼륨헤더페이지(*PAGE_VOLHEADER*)와 섹터테이블 페이지(*PAGE_VOLBITMAP*)로 구분되었다. 이와 유사하게 파일또한 다음과 같이 페이지들로 구분된다.

* **파일 테이블 페이지 (*PAGE_FTAB*)**: 파일내의 페이지 관리를 위한 정보를 담고 있는 페이지
  * **파일 헤더 페이지**: 파일의 예약섹터정보, 페이지할당정보 등을 지니고 있다. 파일 헤더 페이지 또한 파일에 대한 메타데이터와 함께 파일 테이블들을 지니고 있고 페이지 타입이 *PAGE_FTAB*이다.
  * **파일 테이블 페이지**: 파일 내의 페이지들의 할당정보를 담고 있는 페이지. 파일 테이블은 볼륨으로부터 할당받은 섹터마다 섹터의 어떤 페이지들이 할당되어 사용되고 있는지를 추적한다. 테이블 페이지의 종류에 따라 페이지 할당 비트맵을 포함하지 않을수도 있다.
* **유저 페이지 (PAGE_*)**: 페이지 테이블 페이지를 제외한 페이지들을 말한다. 파일의 용도에 따라 여러가지 페이지 타입이 될 수 있다. 

> 파일 헤더페이지가 반드시 파일의 첫번째 페이지인 것은 아니다. 이는 Vacuum의 dropped file과 관련된 것으로 보인다. 추후 MVCC, VACUUM 관련글에서 다뤄보도록 하겠다.

>  **페이지의 타입 (참고용)**
>
>  ```c
>  typedef enum 
>  {
>  PAGE_UNKNOWN = 0,     /* used for initialized page */
>  PAGE_FTAB,            /* file allocset table page */
>  PAGE_HEAP,            /* heap page */
>  PAGE_VOLHEADER,       /* volume header page */
>  PAGE_VOLBITMAP,       /* volume bitmap page */
>  PAGE_QRESULT,         /* query result page */
>  PAGE_EHASH,           /* ehash bucket/dir page */
>  PAGE_OVERFLOW,        /* overflow page (with ovf_keyval) */
>  PAGE_AREA,            /* area page */
>  PAGE_CATALOG,         /* catalog page */
>  PAGE_BTREE,           /* b+tree index page (with ovf_OIDs) */
>  PAGE_LOG,         /* NONE - log page (unused) */
>  PAGE_DROPPED_FILES,       /* Dropped files page.  */
>  PAGE_VACUUM_DATA,     /* Vacuum data. */
>  PAGE_LAST = PAGE_VACUUM_DATA
>  } PAGE_TYPE;
>  ```

<br/>

## 파일 헤더 (*FILE_HEADER*)

---

각 파일마다 기본적으로 한개의 파일헤더페이지를 지니고, 파일헤더페이지의 첫 부분에는 파일헤더(*FILE_HEADER*)가 들어간다. 파일 헤더에는 파일에 대한 기본적인 정보(파일타입과 무관하게 공통적으로 가지는 정보들), 파일이 예약한 섹터들, 파일 내에서 할당된 페이지들을 관리하기 위한 정보들이 들어가 있다. 또한 numerable, temp file의 연산을 위한 캐싱변수들이 포함된다. 이를 정리해보면 다음과 같다.  

***FILE_HEADER***

<table>
  <tr>
    <th>타입 </th>
    <th>변수</th>
    <th>설명</th>
  </tr>
  <tr>
    <td rowspan="11">파일 정보</td>
    <td>INT64 time_creation</td>
    <td>파일이 만들어진 시간</td>
  </tr>
  <tr>
    <td>VFID self</td>
    <td>자기식별자 (fileid, volid) </td>
  </tr>
  <tr>
    <td>FILE_TABLESPACE tablespace</td>
    <td>파일확장시 최소, 최댓값 등이 담김 <br>볼륨과는 다르게 총 확장가능한 최댓값이 아니라, 한 확장연산시 확장량을 결정한다.</td>
  </tr>
  <tr>
    <td>FILE_DESCRIPTORS descriptor</td>
    <td>파일타입에 따른 논리적인 식별자</td>
  </tr>
  <tr>
    <td>FILE_TYPE type</td>
    <td>파일 타입</td>
  </tr>
  <tr>
    <td>INT32 file_flags</td>
    <td>파일의 속성, 현재는 임시파일인지와 numerable인지의 여부가 담김. <br>FILE_FLAG_NUMERABLE/TEMPORARY</td>
  </tr>
  <tr>
    <td>VPID vpid_sticky_first</td>
    <td>파일의 sticky page로 페이지할당해제의 대상이 되지 않는다. </td>
  </tr>
  <tr>
    <td>VOLID volid_last_expand</td>
    <td>파일 확장시 가장 마지막에 섹터를 예약한 볼륨.<br>섹터예약시 어떤 볼륨을 먼저 확인할지 힌트로 사용되기 위한 용도로 보이나, 현재는 사용되고 있지 않다.</td>
  </tr>
  <tr>
    <td>INT16 offset_to_partial_ftab</td>
    <td>파일헤더페이지내에서 partial ftab의 시작위치</td>
  </tr>
  <tr>
    <td>INT16 offset_to_full_ftab</td>
    <td>파일헤더페이지내에서 full ftab의 시작위치</td>
  </tr>
  <tr>
    <td>INT16 offset_to_user_page_ftab</td>
    <td>파일헤더페이지내에서 user page ftab의 시작위치</td>
  </tr>
  <tr>
    <td rowspan="4">페이지 카운트</td>
    <td>int n_page_total</td>
    <td>파일의 총 페이지 수</td>
  </tr>
  <tr>
    <td>int n_page_user</td>
    <td>파일의 유저페이지 수</td>
  </tr>
  <tr>
    <td>int n_page_ftab</td>
    <td>파일의 ftab 페이지 수 </td>
  </tr>
  <tr>
    <td>int n_page_free</td>
    <td>파일의 할당되지 않은 페이지 수</td>
  </tr>
  <tr>
    <td rowspan="4">섹터 카운트</td>
    <td>int n_sector_total</td>
    <td>예약한 총 섹터 수</td>
  </tr>
  <tr>
    <td>int n_sector_partial</td>
    <td>예약한 섹터 중 일부 페이지가 할당에 사용된 섹터 수</td>
  </tr>
  <tr>
    <td>int n_sector_full</td>
    <td>예약한 섹터 중 모든 페이지가 할당에 사용된 섹터 수 </td>
  </tr>
  <tr>
    <td>int n_sector_empty</td>
    <td>예약한 섹터 중 어떤 페이지도 할당에 사용되지 않은 섹터 수<br/>empty sector도 partial sector이다. n_sector_empty &lt;= n_sector_partial</td>
  </tr>
  <tr>
    <td rowspan="2">임시파일을 위한 캐싱 변수</td>
    <td>VPID vpid_last_temp_alloc</td>
    <td rowspan="2">임시파일의 페이지 할당 시 마지막 페이지를 할당받은 partial table의 페이지 ID와 페이지 내부의 offset. <br/>임시파일의 페이지를 할당 받는 위치. 이 후 임시파일을 다룰 때 자세히 다루겠다.</td>
  </tr>
  <tr>
    <td>int offset_to_last_temp_alloc</td>
  </tr>
  <tr>
    <td rowspan="3">Numerable 파일을 위한 캐싱 변수</td>
    <td>VPID vpid_last_user_page_ftab</td>
    <td>마지막으로 할당된 user page에 대한 테이블 엔트리가 추가된 user page ftab 페이지의 ID. <br/>유저페이지 추가시 테이블엔트리를 추가할 위치. 이 후 Numerable 파일을 다룰 때 자세히 다루겠다.</td>
  </tr>
  <tr>
    <td>VPID vpid_find_nth_last</td>
    <td rowspan="2">Numerable파일의 주요 사용처인 external sort를 위한 캐싱변수. 유저페이지에 대한 마지막 순차접근의 위치를 저장한다.</td>
  </tr>
  <tr>
    <td>int first_index_find_nth_last</td>
  </tr>
  <tr>
    <td>예약 변수</td>
    <td>INT32 reserved0/1/2/3</td>
    <td>예약변수</td>
  </tr>
</table>

<br/>

> **Numerable File**
>
> 파일 중 파일테이블 페이지를 제외한 페이지들이 할당될 때, 이들의 할당된 순서를 알 수 있도록 User Page Table을 유지하는 파일이다. Numerable File은 이후에 다시 자세히 다루도록 한다.

> **Sticky Page**
>
> 보통 파일이 만들어질 때, 파일헤더페이지를 제외하고 각 파일타입마다 추가적인 페이지를 할당받고 이를 sticky page로 등록한다. 페이지 할당이 순차적이지 않으므로 파일헤더가 아닌 각 파일타입에 맞는 정보가 담기거나 파일타입에 맞게 파일내의 페이지를 탐색할 수 있는 방법이 필요하며, 이를 sticky page를 통해 해결하는 것으로 보인다.

> **식별자 정리 : VSID, VPID, VFID** 
>
> <table>
>  <tr>
>    <th>타입</th>
>    <th>섹터</th>
>    <th>페이지</th>
>    <th>파일</th>
>  </tr>
>  <tr>
>    <th>int32_t</th>
>    <td>sectid</td>
>    <td>pageid</td>
>    <td>fileid</td>
>  </tr>
>  <tr>
>    <th>short</th>
>    <td>volid</td>
>    <td>volid</td>
>    <td>volid</td>
>  </tr>
> </table>
>
> <br/>volid, sectid, pageid는 각각 순차적으로 부여되는 식별자이다. fileid는 파일이 생성된 페이지(파일헤더페이지)의 pageid를 식별자로써 사용한다. 이를통해 sectid, pageid, fileid를 이용하면 각 개체식별 뿐만 아니라 바로 물리적인 위치를 찾아갈 수도 있다. 

<br/>

## 파일 테이블 페이지

------

파일테이블은 파일내의 페이지들을 관리하기 위한 테이블로 세가지 종류가 있다. 예약한 섹터들의 할당정보를 Partial Sectors Table로 관리하며 테이블의 엔트리는 각 세터별 예약여부에 대한 비트맵이다. 모든 섹터가 예약되면 비트맵은 더 이상 소용없으므로 비트맵없이 Full Sectors Table로 옮겨진다. 유저페이지테이블은 Numerable 속성을 위한 할당순서를 저장한다. 

#### 파일테이블의 종류

- **Partial Sectors Table**: 파일이 예약한 섹터중에서 섹터 내의 모든 페이지가 할당되지 않은 섹터들의 정보를 담고 있다. 테이블의 엔트리는 *FILE_PARTIAL_SECTOR*로 각 섹터의 ID(*VSID*)와 할당여부에 대한 비트맵(*FILE_ALLOC_BITMAP*, UINT64)을 가지고 있다.
- **Full Sectors Table**: 파일의 예약한 섹터 중 섹터 내의 모든 페이지가 할당된 섹터들의 정보를 담고 있다. 테이블의 엔트리는 각 섹터의 ID(*VSID*)이다. 
- **User Page Table**: 위의 둘과는 다르게 페이지를 할당 후 할당된 페이지들을 할당된 순서대로 담고 있다. 테이블의 엔트리는 각 페이지의 ID(*VPID*)이다. Numerable File의 경우에만 이러한 테이블이 생성된다.

> **파일헤더페이지 내의 파일테이블들**
>
> 오롯이 파일테이블만을 위해 할당된 페이지들은 각 종류에 맞는 파일테이블만을 가지는 반면에 파일헤더페이지에는 파일헤더(*FILE_HEADER*)와 함께 세가지 종류의 테이블이 모두 들어간다. 이때 파일헤더를 제외하고, Numerable의 경우 Partial Sectors: Full Sectors : User page =   1:1:30, Numerable이 아닐 경우는 1:1:0 의 비율로 페이지테이블들이 생성된다.

#### 동적인 크기의 파일테이블페이지

파일테이블 페이지의 경우 볼륨의 섹터테이블과는 다르게 크기가 유동적이다. 볼륨의 경우는 최대크기가 정해져 있고 최대크기를 커버할 수 있는 만큼만 섹터테이블이 존재하면 되므로 볼륨이 최초에 생성될 때 고정된 양의 페이지를 사용하여 섹터테이블을 생성하지만, 파일의 경우는 파일의 확장과 사용도에 따라 파일테이블을 추가로 할당 받아야 한다.  또, 필요한 순간에 추가로 파일테이블페이지를 할당받으므로 이들은 물리적으로 연속적이지 않고 흩어져 있으며, 포인터로 연결되어 있다. 

<br/>앞서 말한 파일테이블에 관한 내용을 그림으로 정리하면 다음과 같다. 한 파일내에서 유저페이지를 제외한 시스템 테이블 페이지(파일헤더페이지를 포함한)들의 관계를 개념적으로 표현한 것이다. 물리적으로 파일테이블페이지들은 유저페이지와 함께 볼륨내 임의의 위치에 할당되어 있다. 파일헤더페이지는 파일헤더와 세가지 종류의 테이블이 들어 갈 수 있으며 파일의 사용도에 따라 각 테이블은 추가적인 파일테이블페이지와 연결된다.  

{% include image.html url="disk-file-manager/ftab_architecture.png" description="파일테이블 구조"%}

> 참고로, 파일테이블들을 모두 순회해보면 어떤 섹터의 어떤페이지가 현재 파일에 할당되어 있는지를 알 수는 있지만, 파일테이블 순회없이 파일내 임의의 페이지에 바로 접근할 수 있는 방법은 없다. 만약 파일의 용도에 따라 할당받은 페이지들을 이후에 빠르게 접근하고 싶다면 그러한 기능은 해당 파일타입이 직접 제공해야한다. 예를들어 힙파일(Heap FIle)의 경우에는 다음 힙페이지로의 링크를 레코드로 저장해둔다. 파일매니저나 파일테이블의 역할은 단순히 페이지의 할당까지만이다.

<br/>

---

이어서 다룰 파일매니저 내용은 다음과 같다.

1. 페이지 할당/해제, 파일확장
2. 파일의 생성과 파괴, File Tracker and File Temp Cache
4. Numerable 파일