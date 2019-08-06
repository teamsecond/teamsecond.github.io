---
title: "[File/Disk Manager] 페이지 할당은 어떻게 이루어질까?"
layout: post
author: Jaeeun Kim
categories:
  - cubrid-internal
summary: 큐브리드 파일 페이지 할당 <br/> (CUBRID File Page Allocation)
---

# **페이지 할당은 어떻게 이루어질까?**

 이번 글에서는 이전에 살펴본 파일의 구조를 바탕으로 파일매니저의 주된 역할인 페이지할당이 어떻게 이루어지는지 살펴본다. 페이지 할당과정은 디스크매니저의 섹터예약과정과 유사하며, 좀 더 단순하다. 페이지할당정보를 [이전 글](./disk-file-manager-file-arch)에서 살펴본 것처럼 파일테이블을 통해 관리하고 있으므로, 이를 변경하고 메타데이터인 파일헤더를 변경한다. 페이지할당 과정을 이해하기위해서는 파일테이블에 대하여 알아야 한다. 이를 위해 파일테이블을 구성하는 FILE Extendible Data라는 포맷을 알아보고, 이를 바탕으로 페이지 할당이 어떤식으로 이루어지는지 살펴보자. 또한 임시파일의 경우에는 어떻게 이러한 과정이 단순화될 수 있는지도 임시파일의 페이지할당과정과 함께 살펴본다.

이 포스트는 다음과 같은 내용을 다룬다.

- File Extendible Data
- 페이지 할당
  - 영구 파일
  - 임시 파일
- 페이지 할당 해제

<br/>

## **File Extendible Data**

---

섹터테이블은 볼륨이 만들어질 때 최대크기를 기준으로 생성되는 정적인 구조인데에 비해, 파일테이블들은 파일의 크기에 따라 동적인 크기를 가지는 구조이다([이전 글](./disk-file-manager-file-arch)). 이를 위해 사용된 File Extendible Data는 이론적으로 무제한의 데이터를 여러 디스크 페이지들 안에 담고 이를 연결시킬 수 있도록 해주는 일반화된 포맷이다. 이 포맷은 파일테이블들(Partial/Full Sectors Table, User Page Table), 파일 트래커(File Tracker)등에서 사용된다.

####  **File Extendible Data Format**

구조는 단순하다. 헤더와 아이템(Item, 데이터)의 셋(set)으로 이루어진 컴포넌트들의 리스트(Singly Linked List)이다. 이를 도식화 해보면 다음과 같다.

{% include image.html url="disk-file-manager/file_extendible_data.png" description="File Extendible Data Format"%}

헤더(*FILE_EXTDATA_HEADER*)는 헤더가 포함된 컴포넌트의 아이템의 갯수(*n_items*), 아이템의 크기(*size_of_item*), 컴포넌트의 최대 크기(*max_size*), 다음 컴포넌트로의 링크(*vpid_next*)를 가지고 있다. 여기서 각 변수들은 모두 헤더가 포함된 컴포넌트내의 정보이다. 즉, 전체 아이템의 갯수를 알기 위해서는 모든 컴포넌트의 헤더를 순회하며 *n_item*을 모두 더해야 한다. [이전 글](./disk-file-manager-file-arch)에서 살펴본 여러 페이지에 흩어져 있는 파일 테이블들이 연결되어 있게 해주는 구조가 이 File Extendible Data이다. 페이지 ID(*vpid*)를 통해 연결되므로 첫 컴포넌트는 디스크 페이지내의 어떤 위치에 들어가도 상관 없지만, 이 후의 컴포넌트들은 각 디스크 페이지의 첫 부분에 컴포넌트가 존재해야한다. 

#### **File Extendible Data Operations**

 관련 연산은 Item append, insert, remove, update, merge, search, size 등 일반적인 Container류 자료구조의 연산들로 이루어져 있으며 다음과 같은 특성을 지닌다. 

- remove, insert 등은 항상 삽입/제거 위치 뒤에 있는 모든 데이터의 memmove()연산이 일어남
- merge, search 등은 Item들이 ordered, unordered이냐에 따라 분기된다. ordered일 경우 search시 이진탐색이 가능하다. 

각 연산들의 구현은 대부분 포맷과 같이 단순하여 설명을 생략하고 필요할 경우에는 사용되는 곳에서 함께 이야기하도록 한다.

> 탐색을 위해 VSID로 정렬되어 있는 Full/Partial Sectors table이 ordered의 예이다.

#### **File Table Item**

File Extendible Data의 각 아이템은 어떠한 포맷이라도 올 수 있다. 파일 테이블 세종류 모두 이러한 구조를 통해 이루어져 있지만 아이템은 각각 다르다. 단순히 예약여부, 할당여부를 판단하는 경우 (Full, User)는 ID만을 가지고 있는 반면에 각 섹터들내의 할당여부를 트래킹하는 경우(Partial)는 섹터내의 페이지들에 대한 비트맵을 가지고 있다. 

- Partial Sectors Table: *FILE_PARTIAL_SECTOR*(*VSID*, *FILE_ALLOC_BITMAP*)
- Full Sectors Table: *VSID*
- User Page Table: *VPID*

<br/>

## **페이지 할당** 
---

파일매니저는 디스크매니저로부터 예약한 섹터들을 파일이 필요로 할 경우 페이지단위로 공간을 할당한다. 영구파일과 임시파일은 페이지 할당을 위하여 페이지를 관리하는 방법도 다르고, 페이지를 할당하는 방법도 다르다. 다음의 공통 인터페이스(*file_alloc()*)를 통해 파일타입에 따라 각각 *file_alloc_perm(), file_alloc_temp()*로 분기되어 페이지를 할당 한다.

```c
int
file_alloc (THREAD_ENTRY * thread_p, const VFID * vfid, 
            FILE_INIT_PAGE_FUNC f_init, void *f_init_args, 
            VPID * vpid_out, PAGE_PTR * page_out)
```

페이지가 할당된 후에는 Numerable 파일의 경우에는 User Page Table에 페이지를 추가한 후, 인자로 받은 페이지 초기화 함수(*f_init*)을 통해 디스크페이지의 내용을 초기화한다. 이 떄 이 초기화 함수는 각 파일의 타입(HEAP, BTREE 등)에 맞게 페이지를 포매팅한다. 

#### **영구파일의 페이지 할당**
큐브리드 파일의 페이지 할당은 디스크 매니저의 [섹터예약](./disk-file-manager-sector-reservation)과 유사하다. 할당과정 자체는 유사하면서 파일은 볼륨과 다르게 논리적인 단위이기에 좀 더 단순하다. 페이지 할당은 기본적으로 한 페이지씩 수행하며, 파일테이블에서 할당되지 않은 페이지를 찾아 할당 표시를 한다. 영구파일의 페이지 할당의 주요 과정은 다음과 같다. (*file_alloc(), file_perm_alloc()*) 

1. 파일헤더를 확인하여 파일이 예약한 섹터 중 가용 페이지(fhead->n_page_free)가 없다면 파일(*file_perm_expand()*)을 확장한다.
2. 파일헤더의 Partial Sectors Table에 아이템이 하나도 없다면, 링크로 연결된 다음 파일테이블에서 파일헤더의 파일테이블 크기만큼을 가져온다 (*file_table_move_partial_sectors_to_header()*).
3. 파일헤더의 Partial Sectors Table의 첫 번째 아이템(*file_extdata_start()*)에 페이지 할당 비트를 하나 SET 한다(*file_partsec_alloc()*). 
4. 파일헤더의 Partial Sectors Table에서 페이지를 할당한 섹터아이템의 모든 페이지가 할당되었으면 해당 아이템을 Full Sectors Table로 옮긴다.

1에서  *file_perm_expand()*는 디스크매니저에게 추가적인 섹터예약을 요청(*disk_reserve_sectors()*)한다. 이 때, 확장크기 정보는 파일 헤더의 *tablespace*에 담겨 있고, 이때 파일헤더의 Partial Sectors Table을 넘어가지 않을 정도로만 확장한다. 이 크기를 넘어갈 경우 추가적인 파일테이블 페이지 할당 등 로직이 복잡해져 제한을 둔 듯하다.

2,3에서 항상 Partial Sectors Table의 첫번째 아이템에서 페이지를 할당하는 것을 보면 알 수 있듯이, 페이지 할당시 이 테이블은 마치 Queue자료구조처럼 가장 앞의 아이템만이 사용된다. 해당 아이템의 모든 페이지가 할당되었을 경우 4에서 바로 Full Sectors Table로 옮겨지므로 항상 첫번째 아이템에는 할당되지 않은 페이지가 있음을 보장할 수 있다.

또한 2에서 다음 파일테이블의 모든 아이템을 가져올 경우 해당 파일테이블 페이지는 할당해제되므로 파일내에 할당되지 않은 페이지가 존재할 경우, 항상 파일헤더페이지에 연결된 다음 Partial Sectors Table 페이지에는 할당가능한 섹터가 존재함이 보장된다. 또한, 이렇게 파일테이블 페이지가 할당해제되는 경우에는 해당 페이지를 페이지할당에 재사용한다 (3, 4과정을 건넘 뜀).

#### **임시파일의 페이지 할당**
임시파일의 페이지 할당은 영구파일의 페이지 할당보다 훨씬 단순한다. 이는 일시적인 데이터를 위한 파일이라는 특성 덕분이다. 영구파일에서 Partial/Full로 섹터를 분류해서 관리하는 것은 이들을 함께 관리하면 시간이 지남에 따라 페이지의 할당과 해제가 반복되면서 점점 가용페이지를 찾는것의 비용이 커질 것이기 때문이다. 하지만 임시파일의 경우 일시적으로 사용하는 파일이므로 단순히 그 순간에 필요한 만큼 페이지를 할당받아 사용하고, 사용이 끝나면파일 자체를 제거한다. 따라서 다음과 같이 페이지를 관리한다.

- Partial/Full Sector Table을 구분해서 사용하지 않는다.
- Partial Sector Table형태의 파일테이블 하나만을 사용하며 순차적으로 섹터내의 페이지를 할당해간다.
- 순차적으로 페이지를 할당하므로 예약을 위하여 마지막에 예약한 위치를 파일헤더에 캐시해두고 다음 할당시 이 위치에서 바로 할당을 수행한다. 파일헤더의 *vpid_last_temp_alloc, offset_to_last_temp_alloc* 변수들이 이를 위한 캐싱변수들이다.
- 페이지 할당 해제를 하지 않는다.

임시파일의 예약과정은 이러한 특성을 그대로 반영한 코드로 설명을 생략한다 (*file_temp_alloc()* 참고).

<br/>

## **페이지 할당 해제** 

---

임시파일의 경우 페이지할당해제과정이 없으므로 영구파일의 경우에 대해서만 살펴본다. 

페이지의 할당해제(*file_dealloc()*)도 [섹터의 예약해제](./disk-file-manager-sector-reservation)와 같이 *log_append_postpone()*를 이용하여 즉시수행하지 않고, 트랜잭션이 완료될때까지 작업을 미룬다. 트랜잭션이 완료될때 수행되는 작업(*file_rv_dealloc_internal(), file_perm_dealloc()*)은 할당할 때와 반대로 해당 페이지가 속한 파일 테이블 (Full/Partial)을 찾아서 속하는 섹터의 비트는 off하는 것이다. 코드를 봤을때 복잡한 이유는 다음과 같이 예외상황들이 많기 때문이다.

- Partial Sectors Table에서 해당 페이지가 속하는 섹터 아이템을 찾았을 경우는 bit OFF 후 끝

- Full Sectors Table에서 찾았을 경우 할당해제하는 페이지를 제외하고 모든 비트가 set된 비트맵을 추가하여 Partial Table로 이동시켜야 함.

- Full Sectors Table에서 제거하는 과정에서 해당 아이템이 마지막 아이템이라면 Full Sectors Table이 있는 페이지를 함께 할당해제 해줘야 함.

- Partial Sectors Table에 추가하는 과정에서 만약 빈공간이 없으면 새로운 Partial Sectors Table Page를 할당해줘야 함.

