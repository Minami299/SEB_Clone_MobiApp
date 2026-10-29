// mcq:   [chapterNo, difficulty, content, [A, B, C, D], correctIndex]
// essay: [chapterNo, difficulty, defaultScore, content]
module.exports = {
  PRM393: {
    prefix: 'PM',
    owner: 'HOS001',
    mcq: [
      [1, 'EASY', 'Which keyword declares a variable whose value can be assigned only once at runtime in Dart?', ['var', 'final', 'dynamic', 'static'], 1],
      [1, 'EASY', 'What is the entry point of every Dart application?', ['void run()', 'void start()', 'void main()', 'int init()'], 2],
      [1, 'MEDIUM', 'What does the null-aware operator `??` do in Dart?', ['Checks if two values are equal', 'Returns the right operand if the left operand is null', 'Casts a value to non-nullable', 'Throws if the value is null'], 1],
      [2, 'EASY', 'Which widget is the root of a Material Design app?', ['Scaffold', 'MaterialApp', 'Container', 'Column'], 1],
      [2, 'EASY', 'Which widget arranges its children vertically?', ['Row', 'Stack', 'Column', 'Wrap'], 2],
      [2, 'MEDIUM', 'Which widget should be used to render a long list of items lazily?', ['ListView.builder', 'Column', 'SingleChildScrollView with Row', 'Stack'], 0],
      [2, 'MEDIUM', 'Inside a Row, which widget makes a child take the remaining available space?', ['Padding', 'Expanded', 'SizedBox', 'Align'], 1],
      [3, 'MEDIUM', 'Which method triggers a rebuild of a StatefulWidget?', ['rebuild()', 'setState()', 'refresh()', 'notifyAll()'], 1],
      [3, 'MEDIUM', 'In the Provider package, which method notifies listeners that state has changed?', ['notifyListeners()', 'setState()', 'emit()', 'update()'], 0],
      [3, 'HARD', 'Which statement about InheritedWidget is correct?', ['It rebuilds the whole app on every change', 'It propagates data down the widget tree and rebuilds dependents when it changes', 'It can only hold primitive values', 'It replaces the build() method'], 1],
      [4, 'EASY', 'Which method pushes a new route onto the Navigator stack?', ['Navigator.pop()', 'Navigator.push()', 'Navigator.replaceAll()', 'Navigator.stack()'], 1],
      [4, 'MEDIUM', 'How do you return a value to the previous screen?', ['Navigator.pop(context, value)', 'Navigator.push(context, value)', 'return value;', 'Navigator.back(value)'], 0],
      [5, 'MEDIUM', 'Which package is commonly used to make HTTP requests in Flutter?', ['http', 'provider', 'path', 'intl'], 0],
      [5, 'HARD', 'Why should parsing of a very large JSON payload be done in a separate isolate?', ['Isolates parse JSON faster than any other approach', 'To avoid blocking the UI thread and dropping frames', 'Because Dart cannot parse JSON on the main isolate', "To reduce the app's install size"], 1]
    ],
    essay: [
      [3, 'MEDIUM', 2, 'Explain the difference between setState and Provider for state management. Give one scenario where each is preferable.'],
      [5, 'HARD', 3, 'Describe how you would implement offline support for an exam app: local storage, sync strategy and conflict handling.']
    ]
  },

  DBI202: {
    prefix: 'DB',
    owner: 'HOS002',
    mcq: [
      [1, 'EASY', 'Which key uniquely identifies each row in a table?', ['Foreign key', 'Primary key', 'Candidate index', 'Composite view'], 1],
      [1, 'EASY', 'In an ER diagram, a rectangle usually represents:', ['Relationship', 'Attribute', 'Entity', 'Constraint'], 2],
      [2, 'EASY', 'Which SQL statement removes all rows but keeps the table structure?', ['DROP TABLE', 'TRUNCATE TABLE', 'DELETE TABLE', 'REMOVE ALL'], 1],
      [2, 'EASY', 'Which clause filters groups after aggregation?', ['WHERE', 'GROUP BY', 'HAVING', 'ORDER BY'], 2],
      [2, 'MEDIUM', 'What does SELECT COUNT(*) return?', ['Number of non-null values in a column', 'Number of rows in the result set', 'Number of columns', 'Sum of all numeric values'], 1],
      [3, 'MEDIUM', 'Which JOIN returns all rows from the left table and the matching rows from the right table?', ['INNER JOIN', 'LEFT JOIN', 'CROSS JOIN', 'SELF JOIN'], 1],
      [3, 'MEDIUM', 'A subquery that references a column of the outer query is called:', ['Scalar subquery', 'Correlated subquery', 'Derived table', 'Recursive CTE'], 1],
      [3, 'HARD', 'Which query finds customers who have never placed an order?', ['INNER JOIN Orders and filter Orders.ID IS NULL', 'LEFT JOIN Orders and filter Orders.CustomerID IS NULL', 'CROSS JOIN Orders', 'RIGHT JOIN Orders and filter Customers.ID IS NOT NULL'], 1],
      [4, 'MEDIUM', 'A table is in 2NF if it is in 1NF and:', ['has no transitive dependencies', 'has no partial dependency on a composite key', 'has no multivalued attributes', 'has no foreign keys'], 1],
      [4, 'HARD', 'BCNF is stricter than 3NF because BCNF requires that:', ['every determinant is a candidate key', 'every attribute is atomic', 'no table has a composite key', 'all tables have a surrogate key'], 0],
      [5, 'MEDIUM', 'Which ACID property guarantees that a committed transaction survives a crash?', ['Atomicity', 'Consistency', 'Isolation', 'Durability'], 3],
      [5, 'HARD', 'Which isolation level prevents dirty reads but still allows non-repeatable reads?', ['READ UNCOMMITTED', 'READ COMMITTED', 'REPEATABLE READ', 'SERIALIZABLE'], 1]
    ],
    essay: [
      [4, 'MEDIUM', 2, 'Normalize the table Order(OrderID, CustomerName, CustomerPhone, ProductID, ProductName, Qty) up to 3NF and justify each step.'],
      [5, 'HARD', 3, 'Explain how a non-clustered index speeds up queries and describe one drawback of having too many indexes.']
    ]
  },

  PRN231: {
    prefix: 'PN',
    owner: 'HOS001',
    mcq: [
      [1, 'EASY', 'Which interface is the basis for LINQ queries over in-memory collections?', ['IEnumerable<T>', 'IDisposable', 'IComparable', 'ICloneable'], 0],
      [2, 'EASY', 'Which attribute marks a class as an API controller in ASP.NET Core?', ['[ApiController]', '[WebApi]', '[Controller]', '[RestApi]'], 0],
      [2, 'MEDIUM', 'Which HTTP status code should a POST return when a resource is created?', ['200', '201', '204', '302'], 1],
      [3, 'MEDIUM', 'Which EF Core method persists tracked changes to the database?', ['Commit()', 'SaveChanges()', 'Flush()', 'Apply()'], 1],
      [4, 'MEDIUM', 'Which scheme is commonly used for stateless API authentication in ASP.NET Core?', ['JWT Bearer', 'Cookie session only', 'Basic over HTTP', 'NTLM'], 0],
      [4, 'HARD', 'Where are services registered for dependency injection in ASP.NET Core 6+?', ['Program.cs via builder.Services', 'web.config', 'AssemblyInfo.cs', 'Global.asax'], 0]
    ],
    essay: [
      [3, 'MEDIUM', 3, 'Compare eager loading, lazy loading and explicit loading in EF Core.']
    ]
  },

  CSD201: {
    prefix: 'CS',
    owner: 'HOS002',
    mcq: [
      [1, 'EASY', 'What is the time complexity of accessing an array element by index?', ['O(n)', 'O(log n)', 'O(1)', 'O(n log n)'], 2],
      [2, 'EASY', 'Which data structure follows LIFO order?', ['Queue', 'Stack', 'Heap', 'Deque'], 1],
      [2, 'MEDIUM', 'Which data structure is typically used for breadth-first traversal?', ['Stack', 'Queue', 'Priority stack', 'Hash set'], 1],
      [3, 'MEDIUM', 'In a binary search tree, an in-order traversal visits nodes in:', ['Random order', 'Sorted ascending order', 'Level order', 'Reverse insertion order'], 1],
      [4, 'MEDIUM', 'What is the average time complexity of quicksort?', ['O(n)', 'O(n log n)', 'O(n^2)', 'O(log n)'], 1],
      [4, 'HARD', 'Which sorting algorithm is stable and guarantees O(n log n) in the worst case?', ['Quicksort', 'Heapsort', 'Merge sort', 'Selection sort'], 2]
    ],
    essay: [
      [3, 'HARD', 3, 'Describe how to delete a node with two children from a binary search tree.']
    ]
  }
};
