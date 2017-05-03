using System;
using System.Collections;
using System.Data.SqlClient;

namespace ChangeCollation
{
    public class ScriptStepCollection : CollectionBase
    {
        public ScriptStep this[int index]
        {
            get { return (ScriptStep) InnerList[index]; }
            set { List[index] = value; }
        }

        public int Add(ScriptStep item)
        {
            if (item == null)
                throw new ArgumentNullException(nameof(item));
            return InnerList.Add(item);
        }

        public void Insert(int index, ScriptStep item)
        {
            if (item == null)
                throw new ArgumentNullException(nameof(item));
            InnerList.Insert(index, item);
        }

        public int IndexOf(ScriptStep item)
        {
            return InnerList.IndexOf(item);
        }

        public bool Contains(ScriptStep item)
        {
            return InnerList.Contains(item);
        }

        public void Remove(ScriptStep item)
        {
            InnerList.Remove(item);
        }

        public void CopyTo(ScriptStep[] array, int arrayIndex)
        {
            InnerList.CopyTo(array, arrayIndex);
        }

        protected override void OnValidate(object value)
        {
            base.OnValidate(value);
            if (!(value is ScriptStep))
                throw new ArgumentException("Can only add ScriptStep to ScriptStepCollection", nameof(value));
        }

        public void Execute(SqlConnection connection, IScriptExecuteCallback callback)
        {
            if (connection == null) throw new ArgumentNullException(nameof(connection));
            if (callback == null) throw new ArgumentNullException(nameof(callback));

            var index = 0;
            callback.ExecutionStarting(this);

            while (index < Count)
            {
                var stepToRun = this[index];
                if (!callback.Progress(stepToRun, index + 1, Count)) break;
                stepToRun.Execute(connection, callback);

                index++;
            }
        }
    }
}