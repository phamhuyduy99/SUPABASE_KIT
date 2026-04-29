---
trigger: always_on
---

//=======================================================================================================================
tất cả suy nghĩ hay kế hoạch tài liệu đều phải bằng tiếng Việt

TẤT CẢ SUY NGHĨ HAY KẾ HOẠCH TÀI LIỆU ĐỀU PHẢI BẰNG TIẾNG VIỆT

TẤT CẢ SUY NGHĨ HAY KẾ HOẠCH TÀI LIỆU ĐỀU PHẢI BẰNG TIẾNG VIỆT RÕ NGHĨA DỄ HIỂU
TRỪ TỪ QUÁ CHUYÊN NGÀNH
//=======================================================================================================================

# Rules for LINGMA — fe-innotary

//-------------------------------------------------------------------------------------------------

## 1. ĐỌC FILE TRƯỚC KHI LÀM

- Bắt buộc đọc tất cả các file liên quan trước khi đưa ra kết luận
- Luôn kèm đường dẫn file khi trả lời
- Nếu không chắc file nào liên quan thì tự search

//-------------------------------------------------------------------------------------------------

## 2. TYPE SYSTEM — QUAN TRỌNG NHẤT

- **Bắt buộc** dùng hoặc kế thừa từ types trong folder:
  `C:\Users\duyph\Desktop\INTRUST\fe-innotary\src\types`

- Thứ tự ưu tiên khi cần type:
  1. Dùng thẳng type có sẵn trong `src/types`
  2. Kế thừa (extends) từ type có sẵn
  3. Tạo file type mới trong folder `src/types/components/` tương ứng — **không
     được sửa folder repositories**

- **Tuyệt đối cấm:**
  - Dùng `any` — thay bằng `unknown` hoặc type cụ thể
  - Thêm `[key: string]: unknown` — phải dùng type tường minh
  - Tạo type inline rồi export kiểu `export type { XxxFormData }` — đưa vào
    folder type
  - Bổ sung `any` để pass lỗi type

- Đọc tất cả file liên quan để tìm type chuẩn, hạn chế dùng `unknown`
- Không comment những gì có từ `any`

//-------------------------------------------------------------------------------------------------

## 3. CODE STYLE

- Dùng folder `constant` — đã có type sẵn rồi
- Tạo file CSS thì dùng `module.scss`
- Chuyển hết tham số truyền vào thành object, kể cả khi chỉ có 1 biến, và bổ
  sung comment tương ứng
- **Khi cần hiển thị giá trị rỗng/null**, dùng `DEFAULT_SHOW_EMPTY_VALUE_TEXT`
  từ `@/core/config` — không hardcode `"-"`, `"—"` hay bất kỳ ký tự thay thế nào
  khác
- Khi search constant liên quan đến empty/placeholder/fallback text, **bắt buộc
  search cả `src/core/config/consts.ts`** chứ không chỉ `src/constant/`

//-------------------------------------------------------------------------------------------------

## 4. COMMENT

- Khi sửa bất kỳ thứ gì, bắt buộc thêm comment giải thích
- Phần logic phức tạp hoặc khó hiểu phải comment siêu chi tiết
- **Cấm xóa** các comment đã có sẵn trong file đang sửa, trừ khi thực sự cần
  thiết hoặc có thay đổi logic

//-------------------------------------------------------------------------------------------------

## 5. PLAN TRƯỚC KHI LÀM — BẮT BUỘC

- Với **mọi task có sửa code**, bắt buộc tạo file plan chi tiết trước khi thực
  hiện
- Tạo file plan tại: `docs/plan-[tên-task].md`
- Nội dung plan phải bao gồm:
  1. Danh sách file sẽ thay đổi
  2. Mô tả cụ thể thay đổi ở từng file
  3. Lý do thay đổi
- **Chờ xác nhận** trước khi bắt đầu sửa code — không tự ý làm khi chưa được
  duyệt
- Nếu phát sinh vấn đề ngoài plan trong lúc làm → dừng lại, hỏi ngay, không tự ý
  xử lý
- Sau khi hoàn thành task → **xóa file plan đi**

//-------------------------------------------------------------------------------------------------

## 6. GIT / COMMIT

- Không tự ý commit khi chưa được cho phép
- Không tự chạy lệnh commit
- Khi được yêu cầu viết commit message: viết bằng **tiếng Anh**, theo format:
  ```
  feat / fix / refactor / chore: nội dung
  ```

//-------------------------------------------------------------------------------------------------

## 7. COMPONENT & FILE STRUCTURE

- Mỗi component chỉ làm **1 việc** — nếu file > 200 dòng thì cân nhắc tách nhỏ
- Tách logic phức tạp ra custom hook riêng trong `src/hooks/`, không để logic
  nặng trong component
- Custom hook phải bắt đầu bằng `use` — ví dụ: `useParticipantTable`,
  `useModalState`
- Không viết business logic trực tiếp trong JSX — đưa ra hàm hoặc hook
- Không hardcode string label/text trực tiếp trong JSX — dùng constant hoặc biến
  có tên rõ nghĩa
- Magic number phải đặt thành named constant trong `src/constant/` — ESLint đã
  bật rule `no-magic-numbers`

//-------------------------------------------------------------------------------------------------

## 8. REACT QUERY — DATA FETCHING

- Ưu tiên dùng **React Query** (`useQuery` / `useMutation`) cho API call — hạn
  chế dùng `useEffect` + `useState` để fetch data trừ khi có lý do rõ ràng
- Query key nên nhất quán và có cấu trúc: `['entity', 'action', params]` — ví
  dụ: `['transaction', 'detail', id]`
- Sau mutation thành công nên `invalidateQueries` hoặc `setQueryData` để sync
  cache
- Không gọi API trực tiếp trong component — phải qua `src/repositories/`
- Cố gắng xử lý đủ 3 trạng thái: `isLoading`, `isError`, `data` — ít nhất không
  được bỏ qua error state hoàn toàn

//-------------------------------------------------------------------------------------------------

## 9. NAMING CONVENTION

### File & Folder

- Component file: `PascalCase` — ví dụ: `ParticipantTable.tsx`,
  `ModalViewParticipant.tsx`
- Hook file: `camelCase` bắt đầu bằng `use` — ví dụ: `useParticipantTable.ts`,
  `useModalState.ts`
- Utility / helper file: `PascalCase` + hậu tố rõ nghĩa — ví dụ: `DateUtils.ts`,
  `StringUtils.ts`
- Repository file: `PascalCase` + hậu tố `Repository` — ví dụ:
  `NotaryTransactionRepository.ts`
- Type file: `PascalCase` khớp với entity — ví dụ: `NotaryTransaction.ts`,
  `Participant.ts`
- Constant file: `camelCase` — ví dụ: `common.ts`, `NotaryTransaction.ts`
- CSS module file: `camelCase.module.scss` — ví dụ:
  `participantTable.module.scss`

### Variable & Function

- Biến, hàm: `camelCase` — ví dụ: `transactionDetail`, `handleViewParticipant`
- Component: `PascalCase` — ví dụ: `ParticipantInformationTable`
- Constant / enum value: `SCREAMING_SNAKE_CASE` — ví dụ: `DEFAULT_PAGE_SIZE`,
  `NOTARY_RECEPTION_METHOD`
- Boolean: bắt đầu bằng `is`, `has`, `can`, `should` — ví dụ: `isLoading`,
  `hasPermission`, `canEdit`
- Handler function: bắt đầu bằng `handle` — ví dụ: `handleSubmit`,
  `handleViewParticipant`
- Async function: tên rõ hành động — ví dụ: `fetchTransactionDetail`,
  `submitForm`
- Type / Interface: `PascalCase` — ví dụ: `TransactionParticipant`,
  `ParticipantData`

//-------------------------------------------------------------------------------------------------

## 10. CODE ORGANIZATION — THỨ TỰ TRONG FILE

### Component file (.tsx)

Sắp xếp theo thứ tự sau:

```
1. Imports
2. Types / Interfaces (nếu cần khai báo local)
3. Constants (nếu chỉ dùng trong file này)
4. Component function
   a. Props destructuring
   b. Hooks (useState, useRef, useQuery...)
   c. Derived state / computed values
   d. Handlers (handleXxx)
   e. Effects (useEffect) — nếu có
   f. Render helpers (renderXxx) — nếu cần
   g. Return JSX
5. Export
```

### Hook file (.ts)

```
1. Imports
2. Types / Interfaces
3. Hook function
   a. State
   b. Refs
   c. Queries / Mutations
   d. Derived values
   e. Handlers
   f. Effects
   g. Return object
```

### Repository file (.ts)

```
1. Imports
2. Class definition
   a. constructor
   b. GET methods
   c. POST methods
   d. PUT methods
   e. DELETE methods
3. Export singleton instance
```

//-------------------------------------------------------------------------------------------------

## 11. ERROR HANDLING

- Không để `catch` block trống — phải log hoặc hiển thị thông báo lỗi cho user
- Không dùng `console.log` trong code production — dùng `console.error` cho lỗi
  thực sự
- Xử lý lỗi API tập trung tại `src/utils/errorHandler.ts` — không xử lý rải rác
- Luôn có fallback UI khi data là `null` / `undefined` — không để crash vì
  optional chaining thiếu

//-------------------------------------------------------------------------------------------------

## 12. PERFORMANCE

- Không dùng inline function / inline object trong JSX props nếu gây re-render
  không cần thiết
- List render phải có `key` ổn định — không dùng `index` làm key nếu list có thể
  thay đổi thứ tự
- Import lodash theo kiểu tree-shaking: `import debounce from 'lodash/debounce'`
  — không `import _ from 'lodash'`
- Ảnh và icon SVG đã có sẵn trong `src/resources/` — không import thêm từ ngoài
  nếu đã có

//-------------------------------------------------------------------------------------------------

## 13. SECURITY & CLEAN UP

- Không commit file `.env`, `.env.development`, `.env.production` — đã có trong
  `.gitignore`
- Không để token, secret key, password dưới bất kỳ dạng nào trong source code
- Xóa hết `console.log` debug trước khi hoàn thành task
- Không để code bị comment out (`// old code`) trong file — xóa hẳn đi
- Không để `TODO` comment mà không có issue/ticket đi kèm

//-------------------------------------------------------------------------------------------------

## 14. IMPORT ORDER

- Thứ tự import theo chuẩn (prettier-plugin-sort-imports đã config):
  1. React core
  2. Thư viện bên ngoài (antd, axios, lodash...)
  3. Alias nội bộ (`@/components`, `@/types`, `@/utils`...)
  4. Relative imports (`./`, `../`)
- Không mix default export và named export trong cùng 1 file nếu không cần thiết

//-------------------------------------------------------------------------------------------------

## 15. SKILLS LIBRARY — Antigravity Awesome Skills

Thư mục: `C:\Users\duyph\Desktop\INTRUST\fe-innotary\skills\` Hướng dẫn đầy đủ:
`C:\Users\duyph\Desktop\INTRUST\fe-innotary\SKILLS_GUIDE.md`

> Thư mục `skills/` đã được gitignore — không commit lên repo.

### Cách dùng với Amazon Q

Amazon Q không có `@skill-name` syntax. Cách dùng: **yêu cầu Q đọc file SKILL.md
trước khi làm task**.

**Cú pháp:**

```
Đọc [đường dẫn SKILL.md] rồi [yêu cầu]
```

**Ví dụ thực tế:**

```
Đọc skills/skills/typescript-expert/SKILL.md rồi fix lỗi type này

Đọc skills/skills/react-best-practices/SKILL.md rồi review component này

Đọc skills/skills/debugger/SKILL.md rồi debug lỗi này cho tôi

Đọc skills/skills/clean-code/SKILL.md rồi refactor function này
```

### Map skill theo task

| Task                               | Skill cần đọc                                      |
| ---------------------------------- | -------------------------------------------------- |
| Fix lỗi TypeScript / type phức tạp | `skills/skills/typescript-expert/SKILL.md`         |
| Review / viết React component      | `skills/skills/react-best-practices/SKILL.md`      |
| Refactor, clean code               | `skills/skills/clean-code/SKILL.md`                |
| Debug lỗi runtime / logic          | `skills/skills/debugger/SKILL.md`                  |
| Debug có hệ thống                  | `skills/skills/systematic-debugging/SKILL.md`      |
| Review code quality / PR           | `skills/skills/code-reviewer/SKILL.md`             |
| Thiết kế feature mới               | `skills/skills/brainstorming/SKILL.md`             |
| Lên plan trước khi code            | `skills/skills/writing-plans/SKILL.md`             |
| State management                   | `skills/skills/react-state-management/SKILL.md`    |
| Type nâng cao                      | `skills/skills/typescript-advanced-types/SKILL.md` |

### Khi nào BẮT BUỘC đọc skill trước

- Gặp lỗi TypeScript phức tạp → đọc `skills/skills/typescript-expert/SKILL.md`
- Viết hoặc review React component → đọc
  `skills/skills/react-best-practices/SKILL.md`
- Refactor file lớn → đọc `skills/skills/clean-code/SKILL.md`
- Bug khó tìm nguyên nhân → đọc `skills/skills/debugger/SKILL.md`

//-------------------------------------------------------------------------------------------------
