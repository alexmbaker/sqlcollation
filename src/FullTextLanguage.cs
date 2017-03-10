namespace AlterCollation
{
    public class FullTextLanguage
    {
        public FullTextLanguage(string name, int lcid)
        {
            Name = name;
            Lcid = lcid;
        }

        public string Name { get; }

        public int Lcid { get; }

        public override string ToString()
        {
            return Name;
        }
    }
}