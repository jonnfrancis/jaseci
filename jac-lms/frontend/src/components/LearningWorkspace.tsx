interface Props {
  children: React.ReactNode;
}

export default function LearningWorkspace({ children }: Props) {
  return (
    <div  className="
      /* Mobile: Scrollable auto-height */
      min-h-[calc(100vh-64px)] 
      flex flex-col 
      gap-4 p-4 

      /* Tablet/Desktop: Fixed height & Grid */
      md:h-[calc(100vh-64px)] 
      md:grid 
      md:grid-cols-12 
      md:overflow-hidden
      relative
    ">
      {children}
    </div>
  );
}
